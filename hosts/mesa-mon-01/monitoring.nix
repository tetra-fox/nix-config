{
  config,
  modules,
  topo,
  ...
}: let
  authUrl = topo.authServerUrl;
in {
  imports = [modules.services.monitoring.unifi];

  sops.secrets."monitoring/grafana_oauth_client_secret" = {
    owner = "grafana";
    group = "grafana";
  };

  lab = {
    monitoring = {
      # needs monitoring/telegram_env in this host's sops file
      telegram.enable = true;

      unifi.enable = true;
      unifi.controllerUrl = "https://${config.lab.net.gateway}";

      extraScrapeConfigs = [
        {
          job_name = "node-haos";
          static_configs = [{targets = ["${config.lab.appliances.haosIp}:9100"];}];
        }
      ];
    };
  };

  services.grafana.settings = {
    auth.disable_login_form = true;

    "auth.generic_oauth" = {
      enabled = true;
      name = "Authentik";
      icon = "signin";
      allow_sign_up = true;
      allow_assign_grafana_admin = true;
      # not a secret
      client_id = "Wn5qil44lN5vTsbO7qDzpjl34ZB0oK2tzD3UrOaE";
      client_secret = "$__file{${config.sops.secrets."monitoring/grafana_oauth_client_secret".path}}";
      scopes = "openid email profile";
      auth_url = "${authUrl}/application/o/authorize/";
      token_url = "${authUrl}/application/o/token/";
      api_url = "${authUrl}/application/o/userinfo/";
      signout_redirect_url = "${authUrl}/application/o/grafana/end-session/";
      login_attribute_path = "preferred_username";
      email_attribute_name = "email";
      role_attribute_path = "contains(groups, 'superadmin') && 'GrafanaAdmin' || contains(groups, 'grafana_editors') && 'Editor' || 'Viewer'";
    };
  };
}
