{
  config,
  modules,
  pkgs,
  ...
}: {
  imports = [
    modules.monitoring.system
    modules.logging.system
  ];

  # journald -> loki -> the grafana provisioned above
  lab.logging.enable = true;

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
        url = "https://192.168.10.1";
        user = "unpoller";
        pass = config.sops.secrets."monitoring/unpoller_password".path;
        verify_ssl = false; # self-signed
        save_dpi = true;
      }
    ];
  };

  lab.monitoring = {
    extraScrapeConfigs = [
      # TODO: fairlane's node-exporter targets (HA, proxmox host, etc.)
      {
        job_name = "unpoller-${config.networking.hostName}";
        static_configs = [{targets = ["127.0.0.1:9130"];}];
      }
    ];
  };

  services.grafana-dashboards.community = with pkgs.grafana-dashboards; [
    unpoller-uap-prometheus
    unpoller-clients-prometheus
    unpoller-usw-prometheus
    unpoller-clients-dpi-prometheus
    unpoller-usg-prometheus
    unpoller-network-prometheus
    unpoller-pdu-prometheus
  ];

  services.grafana.settings = {
    server.root_url = "https://stats.fairlane.tetra.cool/";

    # grafana 26.05+ needs an explicit secret_key (cookie signing)
    security.secret_key = "$__file{${config.sops.secrets."monitoring/grafana_secret_key".path}}";
  };
}
