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
    environment = {
      AUTHENTIK_POSTGRESQL__HOST = "postgres-host";
      AUTHENTIK_POSTGRESQL__NAME = "authentik";
      AUTHENTIK_POSTGRESQL__USER = "authentik";
      AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS = "127.0.0.1/32,::1/128,172.16.0.0/12";
      AUTHENTIK_WEB__WORKERS = "4";
    };
    environmentFiles = siteEnvFile "authentik.env";
    extraOptions = [
      "--shm-size=512m"
      "--add-host=postgres-host:host-gateway"
    ];
  };
in {
  imports = [modules.postgres.system];

  sops.secrets = {
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

  lab.postgres = {
    # 172.16.0.0/12 = docker bridge gateway
    allowedCidrs = ["172.16.0.0/12"];
    roles.authentik = {
      passwordSecret = "auth/pg_pass";
      owns = ["authentik"];
    };
  };

  # gate the docker units on the password being set, otherwise authentik
  # crash-loops on bad creds during the boot race.
  systemd.services = let
    pgDeps = {
      after = [config.lab.postgres.passwordUnits.authentik];
      requires = [config.lab.postgres.passwordUnits.authentik];
    };
  in {
    docker-auth-server = pgDeps;
    docker-auth-worker = pgDeps;
  };

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
      dependsOn = ["auth-server"];
      environment = {
        AUTHENTIK_HOST = "http://auth-server:9000";
        AUTHENTIK_INSECURE = "true";
      };
      environmentFiles = siteEnvFile "authentik-ldap.env";
      extraOptions = ["--add-host=auth-server:host-gateway"];
    };
  };
}
