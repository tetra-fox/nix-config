{
  config,
  lib,
  siteData,
  nixosConfigurations,
  ...
}: let
  cfg = config.lab.logging;
  hn = config.networking.hostName;
  serverEnabled = config.lab.monitoring.server.enable;
  # absolute; loki.dataDir wants a full path (unlike prometheus.stateDir which
  # is relative to /var/lib)
  lokiStateDir = "${siteData}/loki";

  # shared site-topology derivation (same one the monitoring module uses). an agent
  # ships its logs to its site's server's loki; the server ships to its own loopback.
  topo = import ../monitoring/site-topology.nix {inherit lib;} {
    inherit nixosConfigurations;
    hostName = hn;
  };
  inherit (topo) hostsInSite siteServers serverIp multiHost myIp;

  # loki binds the site IP once there's a remote agent shipping logs to it; loopback
  # while single-host. mirrors the monitoring module's bindAddr.
  bindAddr =
    if multiHost && myIp != null
    then myIp
    else "127.0.0.1";

  # where alloy pushes logs: local loki if I'm the server, else my site's server.
  lokiHost =
    if serverEnabled
    then "127.0.0.1"
    else
      # null until the site has a server (single-host bootstrap); falls back to
      # loopback so alloy still starts, just buffers/drops until a server exists.
      (
        if serverIp != null
        then serverIp
        else "127.0.0.1"
      );

  # services that write a logfile instead of (or in addition to) stdout aren't
  # covered by the journald source. generate one file_match + source.file pair
  # per entry. they route through a shared process stage that lifts the level out
  # of the *arr "timestamp|Level|component|msg" format into a label, then on to
  # the loki.write defined in config.alloy. the *arr apps write more detail to
  # their file than to stdout, so this is additive
  fileSourceBlocks = lib.concatMapStrings (s: ''

    local.file_match "${s.job}" {
      path_targets = [{ __path__ = "${s.path}", job = "${s.job}" }]
    }

    loki.source.file "${s.job}" {
      targets    = local.file_match.${s.job}.targets
      forward_to = [loki.process.app_level.receiver]
    }
  '') cfg.fileSources;

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
      # exactly one server per site -- the agents derive their loki target from it.
      # (skip the assert during single-host bootstrap when no server exists yet.)
      assertions = [
        {
          assertion = (lib.length siteServers) <= 1;
          message = "logging: site of '${hn}' has multiple monitoring servers (${lib.concatStringsSep ", " siteServers}); expected exactly one host with lab.monitoring.server.enable";
        }
      ];

      # promtail reached EOL and was removed from nixpkgs; grafana-alloy is the
      # vendor-pointed successor. the nixos module reads *.alloy from /etc/alloy
      # (default configPath) and adds the systemd-journal group so it can read the
      # journal. config lives in config.alloy as a real lintable file; host/port
      # come from the environment via sys.env() so that file stays pure alloy
      services.alloy.enable = true;

      environment.etc."alloy/config.alloy".source = ./config.alloy;

      # alloy reads every *.alloy in the config dir into one namespace, so this
      # file's blocks can forward to the loki.write defined in config.alloy. only
      # emitted when there are file sources to tail
      environment.etc."alloy/file-sources.alloy" = lib.mkIf (cfg.fileSources != []) {
        text = fileSourceBlocks + fileProcessBlock;
      };

      systemd.services.alloy = {
        environment = {
          HOSTNAME = hn;
          # alloy pushes to <LOKI_HOST>:<LOKI_PORT>. on the server that's loopback;
          # on an agent it's the site server's IP (derived). port is the server's
          # loki port (default 3100 everywhere).
          LOKI_HOST = lokiHost;
          LOKI_PORT = toString cfg.lokiPort;
        };
        # the module sets SupplementaryGroups = ["systemd-journal"]; append, don't
        # replace, so alloy keeps journal access while gaining file-read access
        serviceConfig.SupplementaryGroups = cfg.extraGroups;
      };
    })

    # ---- server: receive + store logs (loki) + show them (grafana). one per site ----
    (lib.mkIf (cfg.enable && serverEnabled) {
      services.loki = {
        enable = true;
        dataDir = lokiStateDir;
        configuration = {
          server = {
            # loopback while single-host; binds the site IP once remote agents ship logs
            # here (the monitoring module's server firewall opens :3100 to them).
            http_listen_address = bindAddr;
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
    })
  ];
}
