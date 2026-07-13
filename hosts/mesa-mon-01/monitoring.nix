{
  config,
  modules,
  ...
}: {
  imports = [
    modules.services.monitoring.system
    modules.services.monitoring.unifi
    modules.services.logging.system
  ];

  sops.secrets."monitoring/grafana_oauth_client_secret" = {
    owner = "grafana";
    group = "grafana";
  };

  lab = {
    logging.enable = true;

    monitoring = {
      server.enable = true;
      unifi.enable = true;
      unifi.controllerUrl = "https://192.168.10.1";

      extraScrapeConfigs = [
        # non-NixOS node-exporter targets (not auto-discovered from the flake)
        {
          # scraped over the internal VLAN (inter-VM traffic policy); HAOS's exporter
          # binds all interfaces
          job_name = "node-haos";
          static_configs = [{targets = ["10.10.0.20:9100"];}];
        }
        {
          job_name = "node-milkfish";
          static_configs = [{targets = ["192.168.10.2:9100"];}];
        }
      ];
    };
  };

  services.grafana.settings = {
    # root_url is derived from the stats route in modules/services/monitoring/system.nix

    auth.disable_login_form = true;

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
