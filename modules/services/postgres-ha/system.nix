{
  config,
  lib,
  modules,
  pkgs,
  nixosConfigurations,
  fleet,
  topo,
  caps,
  ...
}: let
  siteData = config.lab.site.dataDir;
  cfg = config.lab.postgres;
  inherit (cfg) ha;

  selfIp = config.lab.site.internalIp;

  haNodeNames = topo.hostsProviding caps.dbHaNode.name;
  haNodeIps = topo.ipsProviding caps.dbHaNode.name;
  otherNodeIps = lib.filter (ip: ip != selfIp) haNodeIps;

  # lets the assertion name the host, instead of a null coercion error mid-string
  haNodesWithoutInternalIp =
    lib.filter (name: nixosConfigurations.${name}.config.lab.site.internalIp == null)
    haNodeNames;

  etcdInitialCluster =
    map (
      name: let
        ip = nixosConfigurations.${name}.config.lab.site.internalIp;
      in "${name}=http://${ip}:2380"
    )
    haNodeNames;

  postgresPkg = cfg.package;

  patroniRestPort = 8008;

  roleSql = import modules.services.postgres.role-sql {inherit lib;};

  dumpScript = import modules.services.postgres.dump {
    inherit pkgs postgresPkg;
    inherit (cfg) backup;
  };

  roleReconcileSql =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (name: role:
      ''
        \getenv ${pwVar name} ${pwEnv name}
      ''
      + roleSql {
        inherit name role;
        passwordVar = pwVar name;
      })
    cfg.roles);

  # neither a psql variable nor an env var can hold a hyphen
  varName = lib.replaceStrings ["-"] ["_"];
  pwVar = name: "pw_${varName name}";
  pwEnv = name: "PGPASS_${lib.toUpper (varName name)}";

  # read back by \getenv. not psql -v, argv is world-readable in /proc/<pid>/cmdline
  roleCredEnv =
    lib.concatStringsSep " " (lib.mapAttrsToList (name: _: ''${pwEnv name}="$(cat "$CREDENTIALS_DIRECTORY/${name}")"'')
      cfg.roles);

  roleLoadCreds =
    lib.mapAttrsToList (name: role: "${name}:${config.sops.secrets.${role.passwordSecret}.path}")
    cfg.roles;

  internalCidr = config.lab.site.internalCidr;

  pgHba =
    [
      "local all all trust"
      "host replication replicator ${internalCidr} scram-sha-256"
    ]
    ++ map (cidr: "host all all ${cidr} scram-sha-256")
    (lib.unique (topo.dbClientCidrs ++ cfg.extraAllowedCidrs ++ [internalCidr]));

  haproxyBackends =
    lib.concatStringsSep "\n"
    (map (name: let
      ip = nixosConfigurations.${name}.config.lab.site.internalIp;
    in "    server ${name} ${ip}:5432 check port ${toString patroniRestPort}")
    haNodeNames);

  haproxyConfig = ''
    global
        maxconn 200
    defaults
        mode tcp
        timeout connect 5s
        # authentik and other pooled clients hold long lived connections.
        # long timeout so their sessions don't die
        option tcpka
        timeout client 24h
        timeout server 24h
    listen postgres-write
        bind ${ha.vip}:5432
        option httpchk GET /primary
        http-check expect status 200
        default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    ${haproxyBackends}
  '';

  selfIndex = lib.lists.findFirstIndex (ip: ip == selfIp) 0 haNodeIps;
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
      {
        assertion = haNodesWithoutInternalIp == [];
        message = "lab.postgres.ha: every db-ha-node needs lab.site.internalIp (etcd and haproxy address peers on the internal VLAN); missing on: ${lib.concatStringsSep ", " haNodesWithoutInternalIp}.";
      }
      {
        assertion = internalCidr != null;
        message = "lab.postgres.ha.enable requires lab.site.internalCidr (pg_hba scopes replication and client auth to the internal VLAN's subnet).";
      }
    ];

    # initialClusterState = "new" is only read on an empty data dir, so a wiped node can't
    # rejoin on its own. runbook in the README
    services = {
      etcd = {
        enable = true;
        name = config.networking.hostName;
        dataDir = "${siteData}/etcd";
        initialCluster = etcdInitialCluster;
        initialClusterState = "new";
        initialClusterToken = "${ha.scope}-etcd";
        listenPeerUrls = ["http://${selfIp}:2380"];
        initialAdvertisePeerUrls = ["http://${selfIp}:2380"];
        listenClientUrls = ["http://${selfIp}:2379" "http://127.0.0.1:2379"];
        advertiseClientUrls = ["http://${selfIp}:2379"];
        # patroni rewrites its lease keys every loop, uncompacted revisions hit the 2G quota
        # and etcd goes read-only. compaction doesn't shrink the file, see the README
        extraConf = {
          AUTO_COMPACTION_MODE = "periodic";
          AUTO_COMPACTION_RETENTION = "1h";
        };
      };

      patroni = {
        enable = true;
        inherit (ha) scope;
        name = config.networking.hostName;
        nodeIp = selfIp;
        otherNodesIps = otherNodeIps;
        postgresqlPackage = postgresPkg;
        # overriding postgresqlDataDir drops the module's StateDirectory, tmpfiles creates it
        dataDir = "${siteData}/patroni";
        postgresqlDataDir = "${siteData}/patroni/pgdata/${postgresPkg.psqlSchema}";
        restApiPort = patroniRestPort;
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
            # fixed path for the reconcile and dump units
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
      # patroni owns the one watchdog device
      settings.Manager.RuntimeWatchdogSec = lib.mkForce "0";

      services = lib.mkMerge [
        {
          # /dev/watchdog exists before the module's udev rule loads, so it never applies and
          # patroni can't become primary. chown too in case the retrigger races
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
              # no postgres OS user here, the local trust line lets patroni in as the postgres role
              User = "patroni";
              RemainAfterExit = true;
              LoadCredential = roleLoadCreds;
            };
            script = ''
              # not /primary: the leader lock can be held while promotion is still read-only,
              # which fails ALTER ROLE. replicas never leave recovery and fall through
              for i in $(seq 1 30); do
                if [ "$(${postgresPkg}/bin/psql -tAqc 'SELECT NOT pg_is_in_recovery()' -h /run/postgresql -U postgres -d postgres 2>/dev/null)" = t ]; then
                  ${roleCredEnv} ${postgresPkg}/bin/psql -v ON_ERROR_STOP=1 -h /run/postgresql -U postgres -d postgres <<'EOF'
              ${roleReconcileSql}
              EOF
                  exit 0
                fi
                sleep 2
              done
              echo "not a read-write leader after 60s; reconcile is the leader's job, exiting 0"
              exit 0
            '';
          };

          postgres-dump = lib.mkIf cfg.backup.enable {
            description = "pg_dumpall from the Patroni leader to ${cfg.backup.dir} (keep newest ${toString cfg.backup.keep})";
            after = ["patroni.service"];
            unitConfig.RequiresMountsFor = [cfg.backup.dir];
            serviceConfig = {
              Type = "oneshot";
              User = "patroni";
              # a wedged nfs write fails the unit instead of hanging
              TimeoutStartSec = "15min";
            };
            # every node runs the timer, only the leader dumps. a failover racing the timer
            # can skip one night, the next run self-heals
            script = ''
              if [ "$(${postgresPkg}/bin/psql -tAqc 'SELECT NOT pg_is_in_recovery()' -h /run/postgresql -U postgres -d postgres 2>/dev/null)" != t ]; then
                echo "not the leader; the dump is the leader's job"
                exit 0
              fi
              ${dumpScript}
            '';
          };
        }

        # installed but nothing auto-starts, so no node bootstraps a partial cluster; clear the
        # hold on all members and deploy together.
        (lib.mkIf ha.bootstrapHold {
          etcd.wantedBy = lib.mkForce [];
          patroni.wantedBy = lib.mkForce [];
          haproxy.wantedBy = lib.mkForce [];
          patroni-role-reconcile.wantedBy = lib.mkForce [];
        })
      ];

      timers = {
        postgres-dump = lib.mkIf cfg.backup.enable {
          wantedBy = lib.optionals (!ha.bootstrapHold) ["timers.target"];
          timerConfig = {
            OnCalendar = cfg.backup.onCalendar;
            Persistent = true;
          };
        };

        # nixpkgs starts keepalived from this timer, not a wantedBy, so the hold goes here
        keepalived-boot-delay = lib.mkIf ha.bootstrapHold {
          wantedBy = lib.mkForce [];
        };
      };

      tmpfiles.rules = [
        "d ${siteData}/etcd 0700 etcd etcd -"
        # patroni creates the versioned leaf itself
        "d ${siteData}/patroni 0750 patroni patroni -"
        "d ${siteData}/patroni/pgdata 0750 patroni patroni -"
        "d /run/postgresql 0755 patroni patroni -"
      ];
    };

    # haproxy binds the VIP on nodes that don't hold it, so it's ready on failover
    boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;

    lab.vrrp = {
      enable = true;
      inherit (ha) vip;
      vrrpInterface = config.lab.site.internalInterface;
      vipInterface = config.lab.site.internalInterface;
      inherit (ha) virtualRouterId;
      priorityIndex = selfIndex;
      unicastSrcIp = selfIp;
      unicastPeers = otherNodeIps;
      instanceName = "pgvip";
      healthCheck = {
        name = "chk_haproxy";
        # haproxy down moves the VIP to a node that can route to the db
        script = "${pkgs.procps}/bin/pgrep -x haproxy";
      };
    };

    # patroni reads these directly, per-role secrets go through LoadCredential
    sops.secrets = lib.mkMerge [
      {
        "postgres/superuser_pass" = lib.mkDefault {owner = "patroni";};
        "postgres/replication_pass" = lib.mkDefault {owner = "patroni";};
      }
      (lib.mapAttrs' (_name: role:
        lib.nameValuePair role.passwordSecret (lib.mkDefault {}))
      cfg.roles)
    ];

    # etcd and the patroni REST api have no auth or TLS, and every mesa host is on the
    # internal VLAN, so only cluster members get in
    networking.firewall.extraInputRules = fleet.allow-from haNodeIps [2379 2380 patroniRestPort];

    # clients reach the VIP across the internal VLAN, and 5432 has scram + pg_hba
    networking.firewall.interfaces.${config.lab.site.internalInterface}.allowedTCPPorts = [5432];
    # the VRRP accept rule comes from modules.services.vrrp.system
  };
}
