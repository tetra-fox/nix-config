{
  config,
  lib,
  modules,
  topo,
  caps,
  ...
}: let
  siteData = config.lab.site.dataDir;
  cfg = config.lab.authentik;

  # full patch tag: no podman-auto-update here, so a floating tag never re-pulls. bump one
  # major at a time, latest patch first
  authentikTag = "2026.8.2";
  authentikDataVol = "${siteData}/authentik/data:/data";
  authentikTemplatesVol = "${siteData}/authentik/custom-templates:/templates";

  dbHost = topo.dbEndpointIp;
  authHost = "auth.${config.lab.site.domain}";

  authentikBase = {
    image = "ghcr.io/goauthentik/server:${authentikTag}";
    labels = config.lab.podman.autoUpdate.containerLabels;
    environment = {
      AUTHENTIK_POSTGRESQL__HOST = "postgres-host";
      AUTHENTIK_POSTGRESQL__NAME = "authentik";
      AUTHENTIK_POSTGRESQL__USER = "authentik";
      # without the edge hosts every login and lockout is attributed to the proxy address.
      # 10.88.0.0/16 is podman's bridge
      AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS =
        lib.concatStringsSep ","
        (["127.0.0.1/32" "::1/128" "10.88.0.0/16"] ++ map (ip: "${ip}/32") topo.edgeHostIps);
      AUTHENTIK_WEB__WORKERS = "4";
      # scheme and host only, no path
      AUTHENTIK_WEB__BASE_URL = "https://${authHost}";
    };
    environmentFiles = [config.sops.templates."authentik.env".path];
    extraOptions = [
      "--shm-size=512m"
      "--add-host=postgres-host:${dbHost}"
    ];
  };
in {
  # options only, the host imports podman.system. without these a host missing podman
  # dies on an undeclared option before the assertion below can explain it
  imports = [
    modules.services.postgres.options
    modules.services.podman.options
  ];

  options.lab.authentik = {
    enable = lib.mkEnableOption "run the authentik SSO containers (server/worker/ldap) on this host";

    # baked into the image and published 1:1
    port = lib.mkOption {
      type = lib.types.port;
      readOnly = true;
      default = 9000;
    };

    ldapPort = lib.mkOption {
      type = lib.types.port;
      default = 3389;
      description = "host port the LDAP outpost is published on (internal VLAN); the container side stays 3389";
    };
  };

  config = lib.mkIf cfg.enable {
    lab = {
      topology = {
        # authLdap has no nix consumer, jellyfin's ldap plugin is configured by hand
        provides = [caps.authServer.name caps.authLdap.name];
        routes = [
          {
            host = authHost;
            inherit (cfg) port;
            # podman's published port DNATs before the input chain
            openFirewall = false;
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
          # internal VLAN only, the edge proxies from there
          ports = [
            "${config.lab.site.internalIp}:${toString cfg.port}:${toString cfg.port}"
            "${config.lab.site.internalIp}:9444:9443"
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
          # the image ships its own blueprints under /blueprints
          volumes = [
            authentikDataVol
            "${siteData}/authentik/certs:/certs"
            authentikTemplatesVol
            "${./blueprints}:/blueprints/custom:ro"
          ];
        };

      auth-ldap = {
        image = "ghcr.io/goauthentik/ldap:${authentikTag}";
        labels = config.lab.podman.autoUpdate.containerLabels;
        dependsOn = ["auth-server"];
        environment = {
          AUTHENTIK_HOST = "http://auth-server:${toString cfg.port}";
          AUTHENTIK_INSECURE = "true";
        };
        ports = ["${config.lab.site.internalIp}:${toString cfg.ldapPort}:3389"];
        environmentFiles = [config.sops.templates."authentik-ldap.env".path];
        # host-gateway has no dnat rule for the internal-vlan-only server port
        extraOptions = ["--add-host=auth-server:${config.lab.site.internalIp}"];
      };
    };

    # plaintext ldap, same internal-VLAN trust model as postgres
    networking.firewall.interfaces.${config.lab.site.internalInterface}.allowedTCPPorts = [cfg.ldapPort];
  };
}
