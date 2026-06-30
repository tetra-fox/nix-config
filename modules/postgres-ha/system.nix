# the HA postgres server stack for a mesa data-tier node: Patroni (manages postgres +
# replication + failover) on top of an etcd consensus cluster, with HAProxy doing
# leader-aware routing and keepalived floating a VIP across the nodes. a db node sets
# lab.postgres.ha.enable instead of lab.postgres.server.enable -- the two server backends
# are mutually exclusive because Patroni owns postgres end to end (it runs the postmaster
# itself via bin_dir, and the nixpkgs module asserts services.postgresql is off).
#
# the roles/owns/extraAllowedCidrs contract is shared with the single-server module: this
# module imports the same modules.postgres.options and reads cfg.roles, so the set of
# databases/owners/passwords has one source. where the single-server module renders
# postgresql.conf + pg_hba + per-boot role oneshots, Patroni instead takes pg_hba from the
# DCS (settings.bootstrap.dcs.postgresql.pg_hba) and bootstraps users once cluster-wide;
# the role passwords + ownership are applied by a leader-gated reconcile oneshot (the
# successor to postgresql-set-<role>-password.service) that runs only on the primary.
#
# node addresses (etcd peers, patroni replication, haproxy backends, keepalived peers) are
# all derived from the site topology (ipsWhere isDbHaNode) so there's no hand-typed node
# list -- adding a fourth db node is just another host with ha.enable.
{
  config,
  lib,
  modules,
  pkgs,
  siteData,
  nixosConfigurations,
  ...
}: let
  cfg = config.lab.postgres;
  ha = cfg.ha;

  topo = import modules.lib.site-topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };

  # this node's internal-VLAN address (east-west db traffic rides ens19). every HA address
  # below is an internalIp; the VIP is on the same VLAN.
  selfIp = config.lab.site.internalIp;

  # every HA node's internal IP, and the others (this node excluded). the topology derive
  # (ipOf) already prefers internalIp, so these are 10.10.0.x.
  haNodeNames = topo.hostsWhere topo.isDbHaNode;
  haNodeIps = topo.ipsWhere topo.isDbHaNode;
  otherNodeIps = lib.filter (ip: ip != selfIp) haNodeIps;

  # name=peerURL pairs for etcd's static bootstrap, one per HA node. the etcd member name
  # is the hostname (unique per node, stable).
  etcdInitialCluster =
    map (
      name: let
        ip = nixosConfigurations.${name}.config.lab.site.internalIp;
      in "${name}=http://${ip}:2380"
    )
    haNodeNames;

  postgresPkg = cfg.package;

  # the reconcile SQL: idempotent role+password+ownership, applied on the leader only.
  # CREATE ROLE/DATABASE IF NOT EXISTS isn't valid SQL, so guard each with a SELECT ... gate
  # via \gexec. runs as the local postgres superuser over the unix socket. Patroni streams
  # the resulting catalog changes to the replicas, so this runs once per cluster in effect.
  roleReconcileSql = let
    # role clauses (superuser/createdb/...) -> "WITH SUPERUSER CREATEDB". empty -> "".
    clauseStr = role:
      lib.concatStringsSep " "
      (lib.mapAttrsToList (c: v: lib.optionalString v (lib.toUpper c))
        (lib.filterAttrs (_: v: v) role.clauses));

    mkRole = name: role: ''
      SELECT 'CREATE ROLE ${name} LOGIN ${clauseStr role}'
        WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${name}')\gexec
      ALTER ROLE ${name} WITH LOGIN ${clauseStr role} ENCRYPTED PASSWORD :'pw_${name}';
    '';

    # one CREATE DATABASE per owned db (idempotent gate), then ownership.
    mkDb = name: db: ''
      SELECT 'CREATE DATABASE "${db}" OWNER ${name}'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db}')\gexec
      ALTER DATABASE "${db}" OWNER TO ${name};
    '';

    # the public-schema owner must be the role for pg 15+ to let it CREATE TABLE; this needs
    # a \connect into each db (a separate statement, can't be in the same gexec).
    mkSchema = name: db: ''
      \connect "${db}"
      ALTER SCHEMA public OWNER TO ${name};
      \connect postgres
    '';

    rolesList = lib.attrsToList cfg.roles;
  in
    lib.concatStringsSep "\n" (
      (map (e: mkRole e.name e.value) rolesList)
      ++ lib.concatMap (e: map (db: mkDb e.name db) e.value.owns) rolesList
      ++ lib.concatMap (e: map (db: mkSchema e.name db) e.value.owns) rolesList
    );

  # psql -v assignments binding each role's password from its loaded credential. the unit
  # loads every role secret via LoadCredential; here we read each into a psql variable so
  # the SQL above can ALTER ROLE ... PASSWORD :'pw_<name>' without the value hitting argv.
  roleCredArgs = lib.concatStringsSep " " (lib.mapAttrsToList (name: _:
    "-v \"pw_${name}=$(cat $CREDENTIALS_DIRECTORY/${name})\"")
  cfg.roles);

  roleLoadCreds =
    lib.mapAttrsToList (name: role: "${name}:${config.sops.secrets.${role.passwordSecret}.path}")
    cfg.roles;

  # the pg_hba lines Patroni writes into the DCS. covers: local socket (trust, for the
  # reconcile oneshot), replication between nodes, every derived fleet client + admin extras,
  # and the whole internal VLAN (nodes + VIP reach each other / clients arrive via the VIP).
  pgHba =
    [
      "local all all trust"
      "host replication replicator 10.10.0.0/24 scram-sha-256"
    ]
    ++ map (cidr: "host all all ${cidr} scram-sha-256")
    (lib.unique (topo.dbClientCidrs ++ cfg.extraAllowedCidrs ++ ["10.10.0.0/24"]));

  # HAProxy: VIP:5432 -> the node answering /primary 200 (leader); VIP:5433 -> /replica
  # (declared, unused). httpchk talks to each backend's Patroni REST on :8008.
  haproxyBackends =
    lib.concatStringsSep "\n"
    (map (name: let
      ip = nixosConfigurations.${name}.config.lab.site.internalIp;
    in "    server ${name} ${ip}:5432 check port 8008")
    haNodeNames);

  haproxyConfig = ''
    global
        maxconn 200
    defaults
        mode tcp
        timeout connect 5s
        timeout client 30m
        timeout server 30m
    listen postgres-write
        bind ${ha.vip}:5432
        option httpchk GET /primary
        http-check expect status 200
        default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    ${haproxyBackends}
    listen postgres-read
        bind ${ha.vip}:5433
        option httpchk GET /replica
        http-check expect status 200
        default-server inter 3s fall 3 rise 2
    ${haproxyBackends}
  '';

  # keepalived priority: db-01 highest so it's the default VIP holder. derived from this
  # node's position in the (sorted, stable) HA node list so it's unique without hardcoding.
  selfIndex = lib.lists.findFirstIndex (ip: ip == selfIp) 0 haNodeIps;
  vrrpPriority = 110 - (selfIndex * 5);
in {
  imports = [modules.postgres.options];

  config = lib.mkIf ha.enable {
    assertions = [
      {
        assertion = !cfg.server.enable;
        message = "lab.postgres.ha.enable and lab.postgres.server.enable are mutually exclusive (Patroni owns postgres; it asserts services.postgresql is off).";
      }
      {
        assertion = ha.vip != null;
        message = "lab.postgres.ha.enable requires lab.postgres.ha.vip (the floating endpoint clients reach).";
      }
      {
        assertion = selfIp != null;
        message = "lab.postgres.ha.enable requires lab.site.internalIp (HA traffic rides the internal VLAN).";
      }
    ];

    # etcd: 3-node static cluster, co-located on the db boxes, on the internal VLAN. no TLS
    # (the internal VLAN is isolated L2 with only the db nodes on it -- the VLAN's isolation
    # is the trust boundary; see README). client URL also on localhost for the local Patroni.
    services.etcd = {
      enable = true;
      name = config.networking.hostName;
      dataDir = "${siteData}/etcd";
      initialCluster = etcdInitialCluster;
      initialClusterState = "new";
      initialClusterToken = "mesa-pg-etcd";
      listenPeerUrls = ["http://${selfIp}:2380"];
      initialAdvertisePeerUrls = ["http://${selfIp}:2380"];
      listenClientUrls = ["http://${selfIp}:2379" "http://127.0.0.1:2379"];
      advertiseClientUrls = ["http://${selfIp}:2379"];
    };

    services.patroni = {
      enable = true;
      scope = ha.scope;
      name = config.networking.hostName;
      nodeIp = selfIp;
      otherNodesIps = otherNodeIps;
      postgresqlPackage = postgresPkg;
      # patroni's own state dir (holds the pgpass file). overriding postgresqlDataDir below
      # disables the module's automatic StateDirectory=patroni, so point dataDir under siteData
      # and create it via tmpfiles (the dir must exist + be writable by the patroni user).
      dataDir = "${siteData}/patroni";
      # a FRESH postgres datadir (not the single-server module's ${siteData}/postgresql/<v>),
      # so the assertion against services.postgresql.dataDir holds and the old data survives
      # as a rollback point through the migration.
      postgresqlDataDir = "${siteData}/patroni/pgdata/${postgresPkg.psqlSchema}";
      restApiPort = 8008;
      # patroni owns /dev/watchdog here for split-brain fencing; systemd's watchdog is
      # disabled below so the single VM watchdog isn't contended.
      softwareWatchdog = true;

      # superuser + replication passwords, identical across nodes, sourced from sops as files.
      environmentFiles = {
        PATRONI_SUPERUSER_PASSWORD = config.sops.secrets."postgres/superuser_pass".path;
        PATRONI_REPLICATION_PASSWORD = config.sops.secrets."postgres/replication_pass".path;
      };

      settings = {
        # etcd3.hosts takes a list of ip:port (verified against patroni 4.1.2 etcd3.py).
        etcd3.hosts = map (ip: "${ip}:2379") haNodeIps;

        bootstrap = {
          dcs = {
            ttl = 30;
            loop_wait = 10;
            retry_timeout = 10;
            maximum_lag_on_failover = 1048576;
            postgresql = {
              use_pg_rewind = true;
              parameters.max_connections = 200;
              pg_hba = pgHba;
            };
          };
          initdb = [
            "encoding=UTF-8"
            "data-checksums"
          ];
        };

        postgresql = {
          authentication = {
            # passwords come from the PATRONI_*_PASSWORD env vars sourced above.
            replication.username = "replicator";
            superuser.username = "postgres";
          };
          # per-node runtime params (the bootstrap.dcs block above is init-only). put the
          # unix socket in /run/postgresql so the reconcile oneshot can reach it at a stable
          # path; tmpfiles creates the dir owned by patroni below.
          parameters.unix_socket_directories = "/run/postgresql";
        };
      };
    };

    # patroni owns the watchdog; drop systemd's claim on /dev/watchdog (the profile sets it
    # via mkDefault) so the two don't contend for the single VM watchdog device.
    systemd.settings.Manager.RuntimeWatchdogSec = lib.mkForce "0";

    services.haproxy = {
      enable = true;
      config = haproxyConfig;
    };

    # let haproxy bind the VIP on every node, not just the one keepalived currently parked it
    # on. without this, haproxy fails to start on the non-VIP nodes (cannot bind a non-local
    # address) and isn't ready to serve the instant the VIP fails over to them.
    boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;

    services.keepalived = {
      enable = true;
      enableScriptSecurity = true;
      vrrpScripts.chk_haproxy = {
        script = "${pkgs.procps}/bin/pgrep -x haproxy";
        interval = 2;
        fall = 2;
        rise = 2;
        weight = 20;
      };
      vrrpInstances.pgvip = {
        interface = "ens19";
        virtualRouterId = 51;
        priority = vrrpPriority;
        # all BACKUP + noPreempt so a recovered node doesn't steal the VIP back and flap.
        state = "BACKUP";
        noPreempt = true;
        # unicast VRRP -- no reliance on L2 multicast on the SDN bridge.
        unicastSrcIp = selfIp;
        unicastPeers = otherNodeIps;
        virtualIps = [
          {
            addr = "${ha.vip}/24";
            dev = "ens19";
          }
        ];
        trackScripts = ["chk_haproxy"];
      };
    };

    # the leader-gated role/password/ownership reconcile. replaces the single-server module's
    # per-role postgresql-set-<role>-password oneshots. runs after patroni is up; exits 0 on a
    # replica (gate on the local REST /primary 200) so it's a no-op everywhere but the leader.
    systemd.services = lib.mkMerge [
      {
        # the patroni module ships a udev rule giving the patroni user /dev/watchdog, but the
        # device pre-exists at boot (the VM exposes an iTCO hardware watchdog), so the rule
        # isn't re-applied unless udev is triggered. patroni's mode=required refuses to start
        # without the watchdog, so re-trigger + settle the rule before patroni starts.
        patroni-watchdog-perms = {
          description = "Apply the patroni /dev/watchdog ownership udev rule before patroni starts";
          before = ["patroni.service"];
          requiredBy = ["patroni.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = [
              "${pkgs.systemd}/bin/udevadm trigger --subsystem-match=misc --action=add"
              "${pkgs.systemd}/bin/udevadm settle"
            ];
          };
        };

        patroni-role-reconcile = {
          description = "Reconcile postgres roles/passwords/ownership on the Patroni leader";
          after = ["patroni.service"];
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            Type = "oneshot";
            # patroni runs postgres as the `patroni` OS user (there is no `postgres` OS user
            # on an HA node). it connects to the postgres superuser role over the local socket,
            # which the `local all all trust` pg_hba line permits.
            User = "patroni";
            RemainAfterExit = true;
            LoadCredential = roleLoadCreds;
          };
          # wait for this node to actually serve as primary before reconciling; a fresh cluster
          # takes a moment to elect. give up quietly if this node never becomes leader (it's a
          # replica) -- the leader's own unit does the work. connect as the postgres superuser
          # role over the socket dir patroni configures (settings.postgresql.parameters below).
          script = ''
            for i in $(seq 1 30); do
              if ${pkgs.curl}/bin/curl -sf http://${selfIp}:8008/primary >/dev/null 2>&1; then
                ${postgresPkg}/bin/psql -v ON_ERROR_STOP=1 -h /run/postgresql -U postgres -d postgres ${roleCredArgs} <<'EOF'
            ${roleReconcileSql}
            EOF
                exit 0
              fi
              sleep 2
            done
            echo "not the leader after 60s; reconcile is the leader's job, exiting 0"
            exit 0
          '';
        };
      }

      # coordinated-cutover hold: the stack is installed but nothing auto-starts, so a
      # freshly-installed node can't bootstrap a partial cluster before every member is up.
      # drop the hold on all members and deploy together to bootstrap the full 3-node cluster.
      (lib.mkIf ha.bootstrapHold {
        etcd.wantedBy = lib.mkForce [];
        patroni.wantedBy = lib.mkForce [];
        haproxy.wantedBy = lib.mkForce [];
        keepalived.wantedBy = lib.mkForce [];
        patroni-role-reconcile.wantedBy = lib.mkForce [];
      })
    ];

    # superuser + replication secrets (shared value across nodes) + the per-role secrets.
    # the superuser/replication secrets are read directly by the patroni unit's start script
    # (via environmentFiles, sourced as the patroni user), so they must be owned by patroni.
    # the role secrets are read by the reconcile oneshot via LoadCredential (root reads, then
    # hands the patroni-run unit a copy), so they don't need an owner override.
    sops.secrets = lib.mkMerge [
      {
        "postgres/superuser_pass" = lib.mkDefault {owner = "patroni";};
        "postgres/replication_pass" = lib.mkDefault {owner = "patroni";};
      }
      (lib.mapAttrs' (name: role:
        lib.nameValuePair role.passwordSecret (lib.mkDefault {}))
      cfg.roles)
    ];

    # internal-VLAN firewall: etcd peer/client, patroni REST, postgres, haproxy frontends.
    # scoped to ens19 (the isolated VLAN) rather than opened globally.
    networking.firewall.interfaces.ens19.allowedTCPPorts = [
      2379
      2380
      5432
      5433
      8008
    ];
    # VRRP (protocol 112) between the keepalived peers on the internal VLAN.
    networking.firewall.extraInputRules = ''
      iifname "ens19" ip protocol vrrp accept
    '';

    systemd.tmpfiles.rules = [
      "d ${siteData}/etcd 0700 etcd etcd -"
      # patroni state dir (pgpass) + the postgres data parent; patroni creates the versioned
      # leaf itself but the parents must exist and be writable by the patroni user.
      "d ${siteData}/patroni 0750 patroni patroni -"
      "d ${siteData}/patroni/pgdata 0750 patroni patroni -"
      # the postgres unix socket dir, owned by the patroni user that runs the postmaster
      "d /run/postgresql 0755 patroni patroni -"
    ];
  };
}
