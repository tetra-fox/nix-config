{
  config,
  lib,
  pkgs,
  modules,
  ...
}: let
  cfg = config.lab.monitoring.unifi;
  hn = config.networking.hostName;
in {
  # declares lab.monitoring.{server.enable,extraScrapeConfigs}, which this file reads and
  # extends; without it the module only evals when the host co-imports monitoring.system
  imports = [modules.services.monitoring.registry];

  options.lab.monitoring.unifi = {
    enable = lib.mkEnableOption "UniFi (unpoller) metrics + dashboards";

    controllerUrl = lib.mkOption {
      type = lib.types.str;
      description = "UniFi controller URL to poll; a site fact, set where unifi.enable is set.";
      example = "https://192.168.10.1";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.lab.monitoring.server.enable;
        message = "lab.monitoring.unifi requires lab.monitoring.server.enable (no prometheus/grafana to scrape/show UniFi otherwise) on host '${hn}'";
      }
    ];

    sops.secrets."monitoring/unpoller_password" = {
      owner = "unpoller-exporter";
      group = "unpoller-exporter";
    };

    # unifi controller side: "Local Only User", limited admin / view only
    services.prometheus.exporters.unpoller = {
      enable = true;
      listenAddress = "127.0.0.1";
      log.quiet = true;
      controllers = [
        {
          url = cfg.controllerUrl;
          user = "unpoller";
          pass = config.sops.secrets."monitoring/unpoller_password".path;
          verify_ssl = false;
          save_dpi = true;
        }
      ];
    };

    lab.monitoring.extraScrapeConfigs = [
      {
        job_name = "unpoller-${hn}";
        static_configs = [{targets = ["127.0.0.1:9130"];}];
      }
    ];

    services.grafana-dashboards.community = with pkgs.grafana-dashboards; [
      unpoller-uap-prometheus
      unpoller-clients-prometheus
      unpoller-usw-prometheus
      unpoller-clients-dpi-prometheus
      unpoller-usg-prometheus
      unpoller-network-prometheus
      unpoller-pdu-prometheus
    ];
  };
}
