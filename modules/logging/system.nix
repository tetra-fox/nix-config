{
  config,
  lib,
  siteData,
  ...
}: let
  cfg = config.lab.logging;
  hn = config.networking.hostName;
  # absolute; loki.dataDir wants a full path (unlike prometheus.stateDir which
  # is relative to /var/lib)
  lokiStateDir = "${siteData}/loki";
in {
  options.lab.logging = {
    enable = lib.mkEnableOption "loki + alloy; journald ships every unit's logs (native services and podman-<name> containers) into the grafana on this host";

    lokiPort = lib.mkOption {
      type = lib.types.port;
      default = 3100;
    };
  };

  config = lib.mkIf cfg.enable {
    services.loki = {
      enable = true;
      dataDir = lokiStateDir;
      configuration = {
        server = {
          # localhost only; grafana proxies to it, nothing else needs it
          http_listen_address = "127.0.0.1";
          http_listen_port = cfg.lokiPort;
          # alloy ships over http on the same port, no separate grpc listener needed
          grpc_listen_port = 0;
        };

        auth_enabled = false;

        common = {
          ring.kvstore.store = "inmemory";
          replication_factor = 1;
          # filesystem storage; one host, no object store or clustering
          path_prefix = lokiStateDir;
          storage.filesystem = {
            chunks_directory = "${lokiStateDir}/chunks";
            rules_directory = "${lokiStateDir}/rules";
          };
        };

        schema_config.configs = [
          {
            from = "2024-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];

        # drop logs older than 31 days. single host, finite disk
        limits_config.retention_period = "744h";
        compactor = {
          working_directory = "${lokiStateDir}/compactor";
          retention_enabled = true;
          delete_request_store = "filesystem";
        };
      };
    };

    # promtail reached EOL and was removed from nixpkgs; grafana-alloy is the
    # vendor-pointed successor. the nixos module reads *.alloy from /etc/alloy
    # (default configPath) and adds the systemd-journal group so it can read the
    # journal. config lives in config.alloy as a real lintable file; host/port
    # come from the environment via sys.env() so that file stays pure alloy
    services.alloy.enable = true;

    environment.etc."alloy/config.alloy".source = ./config.alloy;

    systemd.services.alloy.environment = {
      HOSTNAME = hn;
      LOKI_PORT = toString cfg.lokiPort;
    };

    services.grafana.provision.datasources.settings.datasources = [
      {
        name = "loki";
        type = "loki";
        access = "proxy";
        url = "http://127.0.0.1:${toString cfg.lokiPort}";
      }
    ];

    # Logs + Container Logs dashboards. each picks the loki datasource via a
    # template variable, so they don't hardcode the auto-assigned datasource uid
    services.grafana-dashboards.extras = [./dashboards];
  };
}
