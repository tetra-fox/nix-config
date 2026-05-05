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

    # without this the systemd_unit_ip_{egress,ingress}_bytes metrics
    # are flat zero - systemd only tracks per-unit traffic when ip
    # accounting is enabled, off by default per-unit.
    systemd.settings.Manager.DefaultIPAccounting = true;

    # host-level dashboards monitoring itself owns (node + systemd are always
    # on when this module is enabled). merged with service-module
    # contributions (cadvisor from docker, nvidia from nvidia, etc.).
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

      # base host-level scrapes + per-host extras. service modules append
      # their own scrapes by setting services.prometheus.scrapeConfigs
      # directly; the option's listOf merge concatenates them.
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
        # node_exporter's systemd collector covers basic unit state +
        # uptime; systemd_exporter (below) adds per-unit cpu/mem/restart.
        enabledCollectors = ["systemd" "processes"];
      };

      exporters.systemd = {
        enable = true;
        # default port 9558. binds to 0.0.0.0 by default; pin to loopback.
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
        # grafana 26.05+ requires explicit secret_key (no default); cookie signing.
        security.secret_key = "$__file{${config.sops.secrets."monitoring/grafana_secret_key".path}}";
      };

      declarativePlugins = with pkgs.grafanaPlugins; [
        grafana-clock-panel
        grafana-piechart-panel
      ];

      # dashboards.settings.providers wiring lives in
      # tetra-nurpkgs/modules/grafana-dashboards.nix (imported via flake.nix),
      # which reads services.grafana-dashboards.{community,extras} and writes
      # the providers list directly into grafana provisioning.
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
