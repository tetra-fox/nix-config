{
  config,
  modules,
  topo,
  ...
}: let
  # authentik's public url off the auth-server route (a plain input, same pattern as
  # immich's oauth issuerUrl), so the fqdn isn't restated per endpoint
  authUrl = topo.authServerUrl;
in {
  # the monitoring/logging agent modules come from the server profile and server.enable
  # from mon-host.nix; only the unifi (unpoller) module is an extra here
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
      # the controller is the UDM, the same box as the gateway
      unifi.controllerUrl = "https://${config.lab.net.gateway}";

      extraScrapeConfigs = [
        # non-NixOS node-exporter targets (not auto-discovered from the flake)
        {
          # haosIp is the internal-VLAN leg (inter-VM traffic policy); HAOS's exporter
          # binds all interfaces
          job_name = "node-haos";
          static_configs = [{targets = ["${config.lab.appliances.haosIp}:9100"];}];
        }
        {
          job_name = "node-milkfish";
          static_configs = [{targets = ["${config.lab.appliances.proxmoxIp}:9100"];}];
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
      # the client id authentik assigned to the grafana application (not a secret)
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
