{
  config,
  modules,
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

  # local user on the unifi controller is a view-only "Local Only User"
  # (settings -> admins -> add admin -> limited admin / view only).
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

  lab.observability.communityDashboards = [
    {
      id = 11314;
      revision = 10;
      sha256 = "sha256-2wKs35rC/2OIYCkZYwKaSeCVtwZVyWHVoETUH6iELLw=";
      name = "unpoller-uap";
    }
    {
      id = 11315;
      revision = 9;
      sha256 = "sha256-6T9ZJ5bzIzt9jBql83jNZsLDsx9Fih/dULCrVhYExuU=";
      name = "unpoller-clients";
    }
    {
      id = 11312;
      revision = 9;
      sha256 = "sha256-oZL0fxsI4Q+8vnJTkMJ4FzSdCTijQcbkrvubWu5fAu0=";
      name = "unpoller-usw";
    }
    {
      id = 11310;
      revision = 5;
      sha256 = "sha256-mXHsItiM4LkY/2d4u5jzd9B4JoXpPk34SLEMXjqgw1g=";
      name = "unpoller-clients-dpi";
    }
    {
      id = 11313;
      revision = 9;
      sha256 = "sha256-63+3J4yUC0lppWR2m52eIa1EL+FEWVy86WzimxF9tlE=";
      name = "unpoller-usg";
    }
    {
      id = 11311;
      revision = 5;
      sha256 = "sha256-qybSuaqc11tMpOnPCB6bMWrhubnmxuatfG55cpsrn18=";
      name = "unpoller-network";
    }
    {
      id = 23027;
      revision = 1;
      sha256 = "sha256-V0LVhfi/+9MasGQ2Xu+KS/RFvD20GM2L7huGvTGeU/M=";
      name = "unpoller-pdu";
    }
  ];

  services.grafana.settings = {
    server.root_url = "https://stats.mesa.tetra.cool/";

    # grafana 26.05+ requires explicit secret_key (no default); cookie signing.
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
