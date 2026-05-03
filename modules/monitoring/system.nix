{
  config,
  lib,
  pkgs,
  modules,
  siteData,
  ...
}: let
  cfg = config.lab.monitoring;
  hn = config.networking.hostName;
  promStateDir = "${lib.removePrefix "/var/lib/" siteData}/prometheus";

  # fetch a grafana.com dashboard at build time, rewriting ${DS_PROMETHEUS}
  # to a concrete datasource name. to find the sha256: run with sha256 =
  # lib.fakeHash and copy the real hash from the build error.
  mkCommunityDashboard = {
    id,
    revision,
    sha256,
    name,
    datasource ? "prometheus",
  }: let
    raw = pkgs.fetchurl {
      url = "https://grafana.com/api/dashboards/${toString id}/revisions/${toString revision}/download";
      inherit sha256;
    };
  in
    pkgs.runCommand "${name}.json" {} ''
      ${pkgs.gnused}/bin/sed 's|''${DS_PROMETHEUS}|${datasource}|g' ${raw} > $out
    '';

  # bundle a list of dashboard descriptors into a single directory suitable
  # for grafana provisioning.
  mkCommunityDashboardDir = dashboards:
    pkgs.runCommand "grafana-community-dashboards" {} (
      "mkdir -p $out\n"
      + lib.concatMapStringsSep "\n" (
        d: "cp ${mkCommunityDashboard d} $out/${d.name}.json"
      )
      dashboards
    );
in {
  imports = [modules.observability.system];

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

    busDashboards = config.lab.observability.communityDashboards;
    communityDashboardDir = mkCommunityDashboardDir busDashboards;
  in {
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
    lab.observability.communityDashboards = [
      {
        id = 1860;
        revision = 45;
        sha256 = "sha256-GExrdAnzBtp1Ul13cvcZRbEM6iOtFrXXjEaY6g6lGYY=";
        name = "node-exporter-full";
      }
      {
        id = 22872;
        revision = 1;
        sha256 = "sha256-ZlvD6Gt5dJsv2ud4f0t1AuAIMImL9I9zxoE0Rx9yvzM=";
        name = "systemd-exporter";
      }
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

        # community dashboards fetched from grafana.com (contributed by
        # service modules + monitoring's own host-level ones above), plus
        # per-host extras for one-off local JSONs.
        dashboards.settings.providers =
          lib.optional (busDashboards != []) (mkDashboardProvider "community" communityDashboardDir)
          ++ lib.imap0 (i: path: mkDashboardProvider "extra-${toString i}" path) cfg.extraDashboardDirs;
      };
    };
  };
}
