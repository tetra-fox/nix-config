{
  config,
  modules,
  siteData,
  siteEnvFile,
  ...
}: let
  authentikTag = "2026.2";
  authentikDataVol = "${siteData}/authentik/data:/data";
  authentikTemplatesVol = "${siteData}/authentik/custom-templates:/templates";

  authentikBase = {
    image = "ghcr.io/goauthentik/server:${authentikTag}";
    labels = config.lab.podman.autoUpdate.containerLabels;
    environment = {
      AUTHENTIK_POSTGRESQL__HOST = "postgres-host";
      AUTHENTIK_POSTGRESQL__NAME = "authentik";
      AUTHENTIK_POSTGRESQL__USER = "authentik";
      AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS = "127.0.0.1/32,::1/128,10.88.0.0/16";
      AUTHENTIK_WEB__WORKERS = "4";
    };
    environmentFiles = siteEnvFile "authentik.env";
    extraOptions = [
      "--shm-size=512m"
      # postgres lives on db-01 now (Phase 3); authentik's podman isn't in the netns, it
      # reaches the LAN directly, so just point the host alias at db-01's IP.
      "--add-host=postgres-host:192.168.10.245"
    ];
  };
in {
  sops.secrets = {
    # authentik's db password. used to come from the postgres module's role declaration
    # (back when svc-01 ran the server); now that the server is on db-01, declare it
    # directly here -- authentik still needs it to authenticate to the remote db.
    "auth/pg_pass" = {};
    "auth/authentik_secret_key" = {};
    "auth/ldap_outpost_token" = {};
  };

  sops.templates = {
    "authentik.env".content = ''
      AUTHENTIK_POSTGRESQL__PASSWORD=${config.sops.placeholder."auth/pg_pass"}
      AUTHENTIK_SECRET_KEY=${config.sops.placeholder."auth/authentik_secret_key"}
    '';
    "authentik-ldap.env".content = "AUTHENTIK_TOKEN=${config.sops.placeholder."auth/ldap_outpost_token"}\n";
  };

  # the authentik postgres role + db now live on mesa-db-01 (which declares the role and
  # gates ownership). svc-01 is a pure client here, so there's no local passwordUnit to
  # depend on -- authentik retries the connection on startup until db-01 answers.

  virtualisation.oci-containers.containers = {
    auth-server =
      authentikBase
      // {
        cmd = ["server"];
        ports = [
          "9000:9000"
          "9444:9443"
        ];
        volumes = [
          authentikDataVol
          authentikTemplatesVol
        ];
      };

    auth-worker =
      authentikBase
      // {
        cmd = ["worker"];
        volumes = [
          authentikDataVol
          "${siteData}/authentik/certs:/certs"
          authentikTemplatesVol
        ];
      };

    auth-ldap = {
      image = "ghcr.io/goauthentik/ldap:${authentikTag}";
      labels = config.lab.podman.autoUpdate.containerLabels;
      dependsOn = ["auth-server"];
      environment = {
        AUTHENTIK_HOST = "http://auth-server:9000";
        AUTHENTIK_INSECURE = "true";
      };
      ports = ["127.0.0.1:3389:3389"];
      environmentFiles = siteEnvFile "authentik-ldap.env";
      extraOptions = ["--add-host=auth-server:host-gateway"];
    };
  };
}
