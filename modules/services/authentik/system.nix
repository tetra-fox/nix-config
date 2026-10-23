{
  config,
  lib,
  pkgs,
  modules,
  topo,
  caps,
  ...
}: let
  siteData = config.lab.site.dataDir;
  cfg = config.lab.authentik;

  # full patch tag: no podman-auto-update here, so a floating tag never re-pulls. bump one
  # major at a time, latest patch first
  authentikTag = "2026.8.5";
  authentikDataVol = "${siteData}/authentik/data:/data";
  authentikTemplatesVol = "${siteData}/authentik/custom-templates:/templates";

  dbHost = topo.dbEndpointIp;
  authHost = "auth.${config.lab.site.domain}";

  # a proxy provider, application and group binding per forward_auth route, all served
  # by the embedded outpost. blueprints never delete what they stop declaring, so a
  # route that drops forward_auth leaves its app behind, detached from the outpost
  forwardAuthApps = map (r: rec {
    inherit (r) host;
    title =
      if r.title != null
      then r.title
      else lib.head (lib.splitString "." r.host);
    slug = lib.replaceStrings [" "] ["-"] (lib.toLower title);
  }) (lib.filter (r: lib.elem "forward_auth" r.middlewares) topo.routesInSite);
  q = builtins.toJSON;
  forwardAuthEntries = a: ''
    - model: authentik_providers_proxy.proxyprovider
      id: provider-${a.slug}
      identifiers: { name: ${q "Provider for ${a.title}"} }
      attrs:
        mode: forward_single
        external_host: ${q "https://${a.host}"}
        authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
        invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
    - model: authentik_core.application
      id: app-${a.slug}
      identifiers: { slug: ${q a.slug} }
      attrs: { name: ${q a.title}, provider: !KeyOf provider-${a.slug} }
    - model: authentik_policies.policybinding
      identifiers:
        target: !KeyOf app-${a.slug}
        group: !Find [authentik_core.group, [name, ${q cfg.forwardAuthGroup}]]
      attrs: { order: 0 }
  '';
  forwardAuthBlueprint = pkgs.writeText "forward-auth.yaml" ''
    version: 1
    metadata:
      name: forward-auth
    entries:
    ${lib.concatMapStrings forwardAuthEntries forwardAuthApps}
    - model: authentik_outposts.outpost
      identifiers: { managed: goauthentik.io/outposts/embedded }
      attrs:
        providers:
    ${lib.concatMapStrings (a: "      - !KeyOf provider-${a.slug}\n") forwardAuthApps}'';

  ldapBlueprint = pkgs.writeText "ldap.yaml" ''
    version: 1
    metadata:
      name: ldap
    entries:
    - model: authentik_providers_ldap.ldapprovider
      identifiers: { name: Provider for Jellyfin }
      attrs:
        base_dn: ${q cfg.ldapBaseDn}
        authorization_flow: !Find [authentik_flows.flow, [slug, ldap-bind]]
    ${lib.optionalString (topo.mediaHost != null) ''
      # the dashboard hides apps without a launch url, and an ldap provider has none
      - model: authentik_core.application
        identifiers: { slug: jellyfin }
        attrs: { meta_launch_url: ${q "https://${topo.mediaHost}"} }
    ''}
    # bound to the app directly rather than through jellyfin_users, which jellyfin's
    # user search filters on
    - model: authentik_policies.policybinding
      identifiers:
        target: !Find [authentik_core.application, [slug, jellyfin]]
        user: !Find [authentik_core.user, [username, ${q cfg.ldapBindUser}]]
      attrs: { order: 10 }
  '';

  # the folders users sit under in the admin ui. authentik keeps its outpost accounts
  # under goauthentik.io/outposts and resets that path itself
  usersPath = "${config.lab.site.domain}/users";
  pathsBlueprint = pkgs.writeText "paths.yaml" ''
    version: 1
    metadata:
      name: paths
    entries:
    - model: authentik_stages_user_write.userwritestage
      identifiers: { name: enroll-user-write }
      attrs: { user_path_template: ${q usersPath} }
    - model: authentik_core.user
      identifiers: { username: ${q cfg.ldapBindUser} }
      attrs: { path: ${q "${config.lab.site.domain}/service-accounts"} }
  '';

  # ./assets is mounted read-only at this path under the server's file storage root
  # (/data/media/public), so file fields name it relative to that. an app picks up
  # assets/icons/<slug>.svg by its file name
  assetsDir = "repo";
  assetsBlueprint = pkgs.writeText "assets.yaml" ''
    version: 1
    metadata:
      name: assets
    entries:
    - model: authentik_brands.brand
      identifiers: { default: true }
      attrs:
        branding_logo: /static/dist/assets/icons/icon_left_brand.svg
        branding_favicon: /static/dist/assets/icons/icon_pride_trans.png
        branding_default_flow_background: ${q "${assetsDir}/background.png"}
        branding_custom_css: ${q (builtins.readFile ./assets/custom.css)}
    ${lib.concatMapStrings (icon: ''
      - model: authentik_core.application
        identifiers: { slug: ${q (lib.removeSuffix ".svg" icon)} }
        attrs: { meta_icon: ${q "${assetsDir}/icons/${icon}"} }
    '') (lib.attrNames (builtins.readDir ./assets/icons))}'';

  # copied, not symlinked: links into the store don't resolve inside the container
  blueprintsDir = pkgs.runCommand "authentik-blueprints" {nativeBuildInputs = [pkgs.yq-go];} ''
    mkdir $out
    cp ${./blueprints}/*.yaml $out/
    cp ${forwardAuthBlueprint} $out/forward-auth.yaml
    cp ${ldapBlueprint} $out/ldap.yaml
    cp ${pathsBlueprint} $out/paths.yaml
    cp ${assetsBlueprint} $out/assets.yaml
    for f in $out/*.yaml; do yq e . "$f" > /dev/null; done
    # authentik escapes these when it embeds the brand css and never unescapes them
    if grep -n '[>&]' ${./assets/custom.css}; then
      echo "custom.css: > and & break once authentik embeds it" >&2
      exit 1
    fi
  '';

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
      # seconds a failed-login score lasts before the reputation policies forget it.
      # each failure restarts it
      AUTHENTIK_REPUTATION__EXPIRY = "3600";
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

    forwardAuthGroup = lib.mkOption {
      type = lib.types.str;
      default = "arr_users";
      description = "group bound to every forward_auth route's app; must already exist in authentik";
    };

    ldapBaseDn = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = lib.concatMapStringsSep "," (part: "DC=${part}") (lib.splitString "." config.lab.site.domain);
      description = "base DN of the LDAP outpost, built from the site domain";
    };

    ldapBindUser = lib.mkOption {
      type = lib.types.str;
      default = "ldapservice";
      description = "service account LDAP clients bind and search as; its app password is the bind password";
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
            "${./assets}:/data/media/public/${assetsDir}:ro"
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
            "${blueprintsDir}:/blueprints/custom:ro"
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
