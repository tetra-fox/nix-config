# authentik (SSO/identity): server + worker + ldap outpost, as podman containers.
# the postgres db lives on the site's db server (reached via the site-topology dbServerIp
# derive); this host just runs the app. caddy finds this host via the authServerIp derive
# (keyed on lab.authentik.enable below), so nothing hardcodes where authentik runs.
{
  config,
  lib,
  modules,
  siteData,
  siteEnvFile,
  nixosConfigurations,
  ...
}: let
  cfg = config.lab.authentik;

  authentikTag = "2026.2";
  authentikDataVol = "${siteData}/authentik/data:/data";
  authentikTemplatesVol = "${siteData}/authentik/custom-templates:/templates";

  # the site's postgres server (same derive the arr-stack uses). authentik's podman is
  # not in any netns, so it reaches the db host directly over the LAN.
  dbHost =
    (import ../monitoring/site-topology.nix {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }).dbServerIp;

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
      # postgres lives on the db box; authentik reaches the LAN directly (not netns), so
      # point the host alias at the derived db-server IP.
      "--add-host=postgres-host:${dbHost}"
    ];
  };
in {
  imports = [modules.podman.system];

  options.lab.authentik.enable =
    lib.mkEnableOption "run the authentik SSO containers (server/worker/ldap) on this host";

  config = lib.mkIf cfg.enable {
    sops.secrets = {
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
  };
}
