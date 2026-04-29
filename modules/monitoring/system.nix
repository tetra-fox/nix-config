{
  config,
  lib,
  pkgs,
  siteData,
  ...
}: let
  cfg = config.lab.monitoring;
  hn = config.networking.hostName;
  promStateDir = "${lib.removePrefix "/var/lib/" siteData}/prometheus";
in {
  options.lab.monitoring = {
    extraScrapeConfigs = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [];
    };

    extraDashboardDirs = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
    };
  };

  config = let
    mkDashboardProvider = name: path: {
      inherit name;
      options = {
        inherit path;
        foldersFromFilesStructure = true;
      };
      updateIntervalSeconds = 60;
      allowUiUpdates = true;
    };
  in {
    sops.secrets."monitoring/grafana_secret_key" = {
      owner = "grafana";
      group = "grafana";
    };

    services.prometheus = {
      enable = true;
      stateDir = promStateDir;

      globalConfig = {
        scrape_interval = "15s";
        evaluation_interval = "15s";
      };

      scrapeConfigs =
        [
          {
            job_name = "node-${hn}";
            static_configs = [{targets = ["localhost:9100"];}];
          }
          {
            job_name = "cadvisor-${hn}";
            static_configs = [{targets = ["localhost:8081"];}];
          }
        ]
        ++ cfg.extraScrapeConfigs;

      exporters.node = {
        enable = true;
        enabledCollectors = ["systemd" "processes"];
      };
    };

    services.cadvisor = {
      enable = true;
      port = 8081; # avoid sabnzbd's 8080
    };

    services.grafana = {
      enable = true;
      dataDir = "${siteData}/grafana";

      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = 3000;
        };
        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
        };
        # grafana 26.05+ requires explicit secret_key (no default); cookie signing.
        security.secret_key = "$__file{${config.sops.secrets."monitoring/grafana_secret_key".path}}";
      };

      declarativePlugins = with pkgs.grafanaPlugins; [
        grafana-clock-panel
        grafana-piechart-panel
      ];

      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://localhost:${toString config.services.prometheus.port}";
            isDefault = true;
          }
        ];

        # bundled dashboards every host wants (cAdvisor + node_exporter),
        # plus per-host extras for hardware-specific exporters etc.
        dashboards.settings.providers =
          [(mkDashboardProvider "common" ./dashboards)]
          ++ lib.imap0 (i: path: mkDashboardProvider "extra-${toString i}" path) cfg.extraDashboardDirs;
      };
    };
  };
}
