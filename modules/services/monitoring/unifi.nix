# UniFi observability as a self-contained add-on. unpoller is a vendor-specific
# integration (it polls a UniFi controller), NOT generic observability -- so it lives
# outside modules/monitoring/system.nix and plugs into it through the public interface:
# it self-registers its scrape target via lab.monitoring.extraScrapeConfigs and ships
# its dashboards via services.grafana-dashboards.community.
#
# import-based enablement: a host that has a UniFi network to watch imports this module
# and sets lab.monitoring.unifi.enable = true. it asserts the host is a monitoring
# server (there's no point polling UniFi without a prometheus to scrape it / grafana to
# show it).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lab.monitoring.unifi;
  hn = config.networking.hostName;
in {
  options.lab.monitoring.unifi = {
    enable = lib.mkEnableOption "UniFi (unpoller) metrics + dashboards";

    controllerUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://192.168.10.1";
      description = ''
        UniFi controller URL to poll. default works for both current sites (their
        controllers both sit at 192.168.10.1 -- the per-site VLANs reuse the same
        layout). a site with a controller at a different address overrides this.
      '';
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
          verify_ssl = false; # self-signed
          save_dpi = true;
        }
      ];
    };

    # self-register the scrape target into the monitoring module's public option
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
