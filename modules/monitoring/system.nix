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
  options.lab.monitoring.extraScrapeConfigs = lib.mkOption {
    type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
    default = [];
  };

  config = {
    sops.secrets."monitoring/grafana_secret_key" = {
      owner = "grafana";
      group = "grafana";
    };

    # without this the systemd_unit_ip_{egress,ingress}_bytes series are all zero
    systemd.settings.Manager.DefaultIPAccounting = true;

    services.grafana-dashboards.community = with pkgs.grafana-dashboards; [
      node-exporter-full
      systemd-exporter
    ];

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
            job_name = "systemd-${hn}";
            static_configs = [{targets = ["localhost:9558"];}];
          }
        ]
        ++ cfg.extraScrapeConfigs;

      exporters.node = {
        enable = true;
        enabledCollectors = ["systemd" "processes"];
      };

      exporters.systemd = {
        enable = true;
        # binds to 0.0.0.0 by default; pin to loopback
        listenAddress = "127.0.0.1";
        extraFlags = [
          "--systemd.collector.enable-restart-count"
          "--systemd.collector.enable-ip-accounting"
        ];
      };
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
        # grafana 26.05+ needs an explicit secret_key (cookie signing)
        security.secret_key = "$__file{${config.sops.secrets."monitoring/grafana_secret_key".path}}";
      };

      declarativePlugins = with pkgs.grafanaPlugins; [
        grafana-clock-panel
        grafana-piechart-panel
      ];

      # provider wiring lives in tetra-nurpkgs/modules/grafana-dashboards.nix;
      # it reads services.grafana-dashboards.{community,extras} and writes the providers list
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
      };
    };
  };
}
