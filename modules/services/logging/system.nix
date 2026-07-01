{
  config,
  lib,
  modules,
  fleet,
  siteData,
  nixosConfigurations,
  ...
}: let
  cfg = config.lab.logging;
  hn = config.networking.hostName;
  serverEnabled = config.lab.monitoring.server.enable;
  # loki.dataDir wants a full path, unlike prometheus.stateDir which is relative to /var/lib
  lokiStateDir = "${siteData}/loki";

  topo = import fleet.topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = hn;
  };
  inherit (topo) hostsInSite siteServers serverIp multiHost myIp;

  # reached by both same-box grafana and remote agents, so binds all interfaces; the
  # source-scoped nftables rule (monitoring module) gates access, not loki
  lokiListen =
    if multiHost
    then "0.0.0.0"
    else "127.0.0.1";

  lokiHost =
    if serverEnabled
    then "127.0.0.1"
    else
      # serverIp is null during single-host bootstrap; loopback so alloy still starts
      (
        if serverIp != null
        then serverIp
        else "127.0.0.1"
      );

  # services that log to a file instead of stdout aren't covered by the journald source.
  # one file_match + source.file per entry, routed through a stage that lifts the level
  # out of the *arr "timestamp|Level|component|msg" format into a label
  fileSourceBlocks =
    lib.concatMapStrings (s: ''

      local.file_match "${s.job}" {
        path_targets = [{ __path__ = "${s.path}", job = "${s.job}" }]
      }

      loki.source.file "${s.job}" {
        targets    = local.file_match.${s.job}.targets
        forward_to = [loki.process.app_level.receiver]
      }
    '')
    cfg.fileSources;

  fileProcessBlock = ''

    loki.process "app_level" {
      // arr format: 2026-06-27 06:49:35.8|Info|Component|message
      stage.regex {
        expression = "^[^|]+\\|(?P<level>[A-Za-z]+)\\|"
      }
      stage.labels {
        values = { level = "" }
      }
      forward_to = [loki.write.local.receiver]
    }
  '';
in {
  options.lab.logging = {
    enable = lib.mkEnableOption "loki + alloy; journald ships every unit's logs (native services and podman-<name> containers) into the grafana on this host";

    lokiPort = lib.mkOption {
      type = lib.types.port;
      default = 3100;
    };

    fileSources = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          job = lib.mkOption {
            type = lib.types.str;
            description = "loki `job` label for this file, e.g. \"sonarr\"";
          };
          path = lib.mkOption {
            type = lib.types.str;
            description = "absolute path or glob to tail";
          };
        };
      });
      default = [];
      description = ''
        logfiles to tail in addition to the journal, for services that write to
        a file rather than stdout. alloy must be able to read them; grant access
        via extraGroups.
      '';
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "supplementary groups alloy needs to read fileSources (e.g. \"media\")";
    };
  };

  config = lib.mkMerge [
    # ---- agent: ship logs. runs on every host that opts into logging ----
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = (lib.length siteServers) <= 1;
          message = "logging: site of '${hn}' has multiple monitoring servers (${lib.concatStringsSep ", " siteServers}); expected exactly one host with lab.monitoring.server.enable";
        }
      ];

      # alloy is the successor to the EOL'd promtail
      services.alloy.enable = true;

      environment.etc."alloy/config.alloy".source = ./config.alloy;

      # alloy merges every *.alloy in the dir into one namespace, so these blocks can
      # forward to the loki.write defined in config.alloy
      environment.etc."alloy/file-sources.alloy" = lib.mkIf (cfg.fileSources != []) {
        text = fileSourceBlocks + fileProcessBlock;
      };

      systemd.services.alloy = {
        environment = {
          HOSTNAME = hn;
          LOKI_HOST = lokiHost;
          LOKI_PORT = toString cfg.lokiPort;
        };
        # the module already sets SupplementaryGroups = ["systemd-journal"]; this appends,
        # so alloy keeps journal access
        serviceConfig.SupplementaryGroups = cfg.extraGroups;
      };
    })

    # ---- server: receive + store logs (loki) + show them (grafana). one per site ----
    (lib.mkIf (cfg.enable && serverEnabled) {
      services = {
        loki = {
          enable = true;
          dataDir = lokiStateDir;
          configuration = {
            server = {
              http_listen_address = lokiListen;
              http_listen_port = cfg.lokiPort;
              # alloy ships over http on the same port, no separate grpc listener needed
              grpc_listen_port = 0;
            };

            auth_enabled = false;

            common = {
              ring.kvstore.store = "inmemory";
              replication_factor = 1;
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

            limits_config.retention_period = "744h";
            compactor = {
              working_directory = "${lokiStateDir}/compactor";
              retention_enabled = true;
              delete_request_store = "filesystem";
            };
          };
        };

        grafana.provision.datasources.settings.datasources = [
          {
            name = "loki";
            type = "loki";
            access = "proxy";
            url = "http://127.0.0.1:${toString cfg.lokiPort}";
          }
        ];

        grafana-dashboards.extras = [./dashboards];
      };
    })
  ];
}
