{
  config,
  lib,
  modules,
  fleet,
  nixosConfigurations,
  ...
}: let
  siteData = config.lab.site.dataDir;
  cfg = config.lab.authentik;

  authentikTag = "2026.5";
  authentikDataVol = "${siteData}/authentik/data:/data";
  authentikTemplatesVol = "${siteData}/authentik/custom-templates:/templates";

  dbHost =
    (import fleet.topology {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }).dbEndpointIp;

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
    environmentFiles = [config.sops.templates."authentik.env".path];
    extraOptions = [
      "--shm-size=512m"
      "--add-host=postgres-host:${dbHost}"
    ];
  };
in {
  # options contracts, not the server modules: authentik is a pure postgres client (it only
  # needs the lab.postgres.client flag so the db server allow-lists this host), and it reads
  # lab.podman.autoUpdate.containerLabels without owning the backend. the container backend
  # (podman.system) is imported by the host, not here; without the options import, enabling
  # authentik on a host missing podman would die on the undeclared option before the
  # virtualisation.podman.enable assertion below could explain the problem.
  imports = [
    modules.services.postgres.options
    modules.services.podman.options
  ];

  options.lab.authentik = {
    enable = lib.mkEnableOption "run the authentik SSO containers (server/worker/ldap) on this host";

    ldapPort = lib.mkOption {
      type = lib.types.port;
      default = 3389;
      description = "host port the LDAP outpost is published on (internal VLAN); the container side stays 3389";
    };
  };

  config = lib.mkIf cfg.enable {
    lab = {
      topology = {
        # auth-ldap: the LDAP outpost endpoint, resolvable as ipProviding "auth-ldap" +
        # lab.authentik.ldapPort. no nix consumer yet (jellyfin's ldap plugin is configured
        # by hand), the capability just makes the endpoint discoverable
        provides = ["auth-server" "auth-ldap"];
        routes = [
          {
            host = "auth.${config.lab.site.domain}";
            port = 9000;
          }
        ];
      };
      postgres.client.enable = true;
    };

    assertions = [
      {
        assertion = config.virtualisation.podman.enable;
        message = "authentik runs oci-containers; the host must import a container backend (modules.services.podman.system).";
      }
    ];

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
        ports = ["${config.lab.site.internalIp}:${toString cfg.ldapPort}:3389"];
        environmentFiles = [config.sops.templates."authentik-ldap.env".path];
        extraOptions = ["--add-host=auth-server:host-gateway"];
      };
    };

    # LDAP outpost is reachable from other hosts on the internal VLAN (e.g. jellyfin on
    # mesa-svc-01); plaintext is acceptable here, same trust model as the postgres cluster.
    networking.firewall.interfaces.${config.lab.site.internalInterface}.allowedTCPPorts = [cfg.ldapPort];
  };
}
