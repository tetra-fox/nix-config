{
  config,
  lib,
  modules,
  fleet,
  pkgs,
  siteData,
  nixosConfigurations,
  ...
}: let
  cfg = config.lab.postgres;
  inherit (cfg) ha;

  topo = import fleet.topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };

  selfIp = config.lab.site.internalIp;

  haNodeNames = topo.hostsProviding "db-ha-node";
  haNodeIps = topo.ipsProviding "db-ha-node";
  otherNodeIps = lib.filter (ip: ip != selfIp) haNodeIps;

  etcdInitialCluster =
    map (
      name: let
        ip = nixosConfigurations.${name}.config.lab.site.internalIp;
      in "${name}=http://${ip}:2380"
    )
    haNodeNames;

  postgresPkg = cfg.package;

  # CREATE ROLE/DATABASE IF NOT EXISTS isn't valid SQL, so guard each with a SELECT ... \gexec.
  roleReconcileSql = let
    clauseStr = role:
      lib.concatStringsSep " "
      (lib.mapAttrsToList (c: v: lib.optionalString v (lib.toUpper c))
        (lib.filterAttrs (_: v: v) role.clauses));

    mkRole = name: role: ''
      SELECT 'CREATE ROLE ${name} LOGIN ${clauseStr role}'
        WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${name}')\gexec
      ALTER ROLE ${name} WITH LOGIN ${clauseStr role} ENCRYPTED PASSWORD :'pw_${name}';
    '';

    mkDb = name: db: ''
      SELECT 'CREATE DATABASE "${db}" OWNER ${name}'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db}')\gexec
      ALTER DATABASE "${db}" OWNER TO ${name};
    '';

    # pg 15+: public schema owner must be the role or it can't CREATE TABLE.
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

  # psql -v so the password reaches ALTER ROLE as :'pw_<name>' and never hits argv.
  roleCredArgs =
    lib.concatStringsSep " " (lib.mapAttrsToList (name: _: "-v \"pw_${name}=$(cat $CREDENTIALS_DIRECTORY/${name})\"")
      cfg.roles);

  roleLoadCreds =
    lib.mapAttrsToList (name: role: "${name}:${config.sops.secrets.${role.passwordSecret}.path}")
    cfg.roles;

  # SITE SEAM: 10.10.0.0/24 is mesa's internal VLAN, baked into this "generic" module. a second
  # site with a different internal VLAN forks here -- when it does, that's the signal to
  # parameterize (likely derive from lab.site.internalIp's /24, or a lab.site.internalCidr the
  # site layer sets). left hardcoded on purpose: the second site's actual CIDR reveals the right
  # seam, guessing it now would abstract against imagined variation.
  pgHba =
    [
      "local all all trust"
      "host replication replicator 10.10.0.0/24 scram-sha-256"
    ]
    ++ map (cidr: "host all all ${cidr} scram-sha-256")
    (lib.unique (topo.dbClientCidrs ++ cfg.extraAllowedCidrs ++ ["10.10.0.0/24"]));

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
  '';

  selfIndex = lib.lists.findFirstIndex (ip: ip == selfIp) 0 haNodeIps;
  vrrpPriority = 110 - (selfIndex * 5);
in {
  imports = [modules.services.postgres.options modules.services.vrrp.system];

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

    # etcd + Patroni REST have no TLS/auth; safe only because nothing but db nodes is on
    # 10.10.0.0/24 (enforced in proxmox, not here). add peer/client TLS + REST auth before
    # anything else lands on the VLAN.
    #
    # initialClusterState = "new" is read only on first start of an empty data dir, so
    # reboots are fine, but a wiped/replaced node re-bootstraps a new cluster and fails to
    # join. re-add via etcdctl member add + initialClusterState=existing, or wipe all three
    # and re-bootstrap together. runbook: project_mesa_ip_scheme memory.
    services = {
      etcd = {
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

      patroni = {
        enable = true;
        inherit (ha) scope;
        name = config.networking.hostName;
        nodeIp = selfIp;
        otherNodesIps = otherNodeIps;
        postgresqlPackage = postgresPkg;
        # overriding postgresqlDataDir disables the module's StateDirectory=patroni, so this
        # dir is created via tmpfiles below instead.
        dataDir = "${siteData}/patroni";
        postgresqlDataDir = "${siteData}/patroni/pgdata/${postgresPkg.psqlSchema}";
        restApiPort = 8008;
        softwareWatchdog = true;

        environmentFiles = {
          PATRONI_SUPERUSER_PASSWORD = config.sops.secrets."postgres/superuser_pass".path;
          PATRONI_REPLICATION_PASSWORD = config.sops.secrets."postgres/replication_pass".path;
        };

        settings = {
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
              replication.username = "replicator";
              superuser.username = "postgres";
            };
            # stable socket path so the reconcile oneshot can reach it (tmpfiles creates the dir).
            parameters.unix_socket_directories = "/run/postgresql";
          };
        };
      };

      haproxy = {
        enable = true;
        config = haproxyConfig;
      };
    };

    systemd = {
      # patroni owns the watchdog; drop systemd's claim so they don't contend for the one VM device.
      settings.Manager.RuntimeWatchdogSec = lib.mkForce "0";

      services = lib.mkMerge [
        {
          # /dev/watchdog pre-exists at boot so the module's udev rule granting it to patroni
          # never re-applies; without it patroni's mode=required won't become primary. re-trigger
          # udev (and chown directly, in case that races) before patroni on every node.
          patroni-watchdog-perms = {
            description = "Give the patroni user /dev/watchdog (chown + re-apply the udev rule) before patroni";
            before = ["patroni.service"];
            wantedBy = ["multi-user.target"];
            requiredBy = ["patroni.service"];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = [
                "${pkgs.systemd}/bin/udevadm trigger --subsystem-match=misc --action=add"
                "${pkgs.systemd}/bin/udevadm settle"
                "${pkgs.coreutils}/bin/chown patroni:patroni /dev/watchdog"
              ];
            };
          };

          patroni-role-reconcile = {
            description = "Reconcile postgres roles/passwords/ownership on the Patroni leader";
            after = ["patroni.service"];
            wantedBy = ["multi-user.target"];
            serviceConfig = {
              Type = "oneshot";
              # no `postgres` OS user on an HA node; patroni runs the postmaster, and the local
              # trust line lets this user reach the postgres role over the socket.
              User = "patroni";
              RemainAfterExit = true;
              LoadCredential = roleLoadCreds;
            };
            # reconcile once this node is leader; exit 0 if it never is (a replica's work is the
            # leader's own unit's job, not a failure).
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

        # installed but nothing auto-starts, so no node bootstraps a partial cluster; clear the
        # hold on all members and deploy together.
        (lib.mkIf ha.bootstrapHold {
          etcd.wantedBy = lib.mkForce [];
          patroni.wantedBy = lib.mkForce [];
          haproxy.wantedBy = lib.mkForce [];
          keepalived.wantedBy = lib.mkForce [];
          patroni-role-reconcile.wantedBy = lib.mkForce [];
        })
      ];

      tmpfiles.rules = [
        "d ${siteData}/etcd 0700 etcd etcd -"
        # parents must exist and be patroni-writable; patroni creates the versioned leaf itself.
        "d ${siteData}/patroni 0750 patroni patroni -"
        "d ${siteData}/patroni/pgdata 0750 patroni patroni -"
        "d /run/postgresql 0755 patroni patroni -"
      ];
    };

    # let haproxy bind the VIP on nodes that don't currently hold it, else it can't start
    # there and isn't ready when the VIP fails over.
    boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;

    lab.vrrp = {
      enable = true;
      inherit (ha) vip;
      vrrpInterface = "ens19";
      vipInterface = "ens19";
      virtualRouterId = 51; # 52 = edge, 53 = dns; unique per L2 segment
      priority = vrrpPriority;
      unicastSrcIp = selfIp;
      unicastPeers = otherNodeIps;
      instanceName = "pgvip";
      healthCheck = {
        name = "chk_haproxy";
        # haproxy down drops the VIP so it moves to a node that can route to the db.
        script = "${pkgs.procps}/bin/pgrep -x haproxy";
      };
    };

    # patroni reads these directly (environmentFiles) so they must be patroni-owned; the
    # per-role secrets go through LoadCredential and need no owner override.
    sops.secrets = lib.mkMerge [
      {
        "postgres/superuser_pass" = lib.mkDefault {owner = "patroni";};
        "postgres/replication_pass" = lib.mkDefault {owner = "patroni";};
      }
      (lib.mapAttrs' (name: role:
        lib.nameValuePair role.passwordSecret (lib.mkDefault {}))
      cfg.roles)
    ];

    networking.firewall.interfaces.ens19.allowedTCPPorts = [
      2379
      2380
      5432
      8008
    ];
    # the VRRP accept rule on ens19 comes from modules.services.vrrp.system.
  };
}
