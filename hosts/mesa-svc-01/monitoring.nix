{
  config,
  modules,
  siteData,
  ...
}: {
  imports = [
    modules.monitoring.system
    modules.monitoring.unifi
    modules.logging.system
  ];

  # this host is the mesa site's monitoring server (prometheus + grafana + loki).
  # the only host in the site today, so it scrapes itself; future mesa-svc-NN agents
  # are auto-discovered by the monitoring module from the flake.
  lab.monitoring.server.enable = true;
  lab.monitoring.unifi.enable = true; # mesa has a UniFi network

  # source-scoped peer firewall rules (monitoring module) need the nftables backend
  networking.nftables.enable = true;

  lab.logging = {
    # journald -> loki -> the grafana provisioned above
    enable = true;

    # the *arr apps log more detail to their <name>.txt than to stdout. tail the
    # current (non-rotated) file; sabnzbd/qbittorrent logs are 0600 owner-only so
    # they stay journal-only. media group grants read on these 0644/0664 files
    extraGroups = ["media"];
    fileSources = [
      {
        job = "sonarr";
        path = "${siteData}/sonarr/logs/sonarr.txt";
      }
      {
        job = "radarr";
        path = "${siteData}/radarr/logs/radarr.txt";
      }
      {
        job = "prowlarr";
        path = "${siteData}/prowlarr/logs/prowlarr.txt";
      }
    ];
  };

  sops.secrets."monitoring/grafana_oauth_client_secret" = {
    owner = "grafana";
    group = "grafana";
  };

  lab.monitoring.extraScrapeConfigs = [
    # non-NixOS node-exporter targets (not auto-discovered from the flake)
    {
      job_name = "node-haos";
      static_configs = [{targets = ["172.16.0.10:9100"];}];
    }
    {
      job_name = "node-milkfish";
      static_configs = [{targets = ["172.16.0.2:9100"];}];
    }
  ];

  services.grafana.settings = {
    server.root_url = "https://stats.mesa.tetra.cool/";

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
