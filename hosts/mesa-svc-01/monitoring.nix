{
  config,
  modules,
  pkgs,
  ...
}: {
  imports = [modules.monitoring.system];

  sops.secrets = {
    "monitoring/grafana_oauth_client_secret" = {
      owner = "grafana";
      group = "grafana";
    };
    "monitoring/unpoller_password" = {
      owner = "unpoller-exporter";
      group = "unpoller-exporter";
    };
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
      {
        job_name = "node-haos";
        static_configs = [{targets = ["172.16.0.10:9100"];}];
      }
      {
        job_name = "node-milkfish";
        static_configs = [{targets = ["172.16.0.2:9100"];}];
      }
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
    server.root_url = "https://stats.mesa.tetra.cool/";

    # grafana 26.05+ needs an explicit secret_key (cookie signing)
    security.secret_key = "$__file{${config.sops.secrets."monitoring/grafana_secret_key".path}}";

    auth.disable_login_form = true; # oauth only

    "auth.generic_oauth" = {
      enabled = true;
      name = "Authentik";
      icon = "signin";
      allow_sign_up = true;
      allow_assign_grafana_admin = true;
      client_id = "Wn5qil44lN5vTsbO7qDzpjl34ZB0oK2tzD3UrOaE";
      client_secret = "$__file{${config.sops.secrets."monitoring/grafana_oauth_client_secret".path}}";
      scopes = "openid email profile";
      auth_url = "https://auth.mesa.tetra.cool/application/o/authorize/";
      token_url = "https://auth.mesa.tetra.cool/application/o/token/";
      api_url = "https://auth.mesa.tetra.cool/application/o/userinfo/";
      signout_redirect_url = "https://auth.mesa.tetra.cool/application/o/grafana/end-session/";
      login_attribute_path = "preferred_username";
      email_attribute_name = "email";
      role_attribute_path = "contains(groups, 'superadmin') && 'GrafanaAdmin' || contains(groups, 'grafana_editors') && 'Editor' || 'Viewer'";
    };
  };
}
