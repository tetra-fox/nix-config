{
  config,
  lib,
  pkgs,
  inputs,
  topo,
  ...
}: let
  cfg = config.lab.arrStack;
  vpnNs = "wg";
  host = "reseek.${config.lab.site.domain}";
  webPort = config.services.reseek.settings.web.port;
  media = config.lab.storage.mounts.media.mountpoint;
  music = config.lab.storage.mounts.music.mountpoint;
  authHost = lib.removePrefix "https://" topo.authServerUrl;
in {
  imports = [inputs.reseek.nixosModules.default];

  options.lab.arrStack.reseek = {
    enable = lib.mkEnableOption "reseek, a soulseek daemon with a web ui, in the vpn netns";

    soulseekPort = lib.mkOption {
      type = lib.types.port;
      description = ''
        reseek's soulseek listen port, a second port forwarded by the VPN provider. without
        it peers that are also firewalled can't reach this client at all
      '';
    };
  };

  config = lib.mkIf cfg.reseek.enable {
    assertions = [
      {
        assertion = topo.authServerUrl != null;
        message = "arr-stack: reseek signs in through authentik's oidc, and this site has no auth server.";
      }
    ];

    sops.secrets = {
      "reseek/soulseek_username" = {};
      "reseek/soulseek_password" = {};
      "reseek/admin_password" = {};
      "reseek/oidc_client_secret" = {};
    };

    sops.templates = {
      # default root 0400: systemd reads EnvironmentFile as root
      "reseek.env" = {
        content = ''
          RESEEK_SLSK_USERNAME=${config.sops.placeholder."reseek/soulseek_username"}
          RESEEK_SLSK_PASSWORD=${config.sops.placeholder."reseek/soulseek_password"}
          RESEEK_PASSWORD=${config.sops.placeholder."reseek/admin_password"}
        '';
        restartUnits = ["reseek.service"];
      };

      # read by the daemon itself, so owned by its user. a provider set in a drop-in replaces
      # the whole provider table, so all of the provider is here rather than in settings
      "reseek-oidc.toml" = {
        owner = config.services.reseek.user;
        reloadUnits = ["reseek.service"];
        file = (pkgs.formats.toml {}).generate "reseek-oidc.toml" {
          web.authentication.oidc.authentik = {
            issuer = "${topo.authServerUrl}/application/o/reseek/";
            client_id = "reseek";
            client_secret = config.sops.placeholder."reseek/oidc_client_secret";
            display_name = "Authentik";
            # authentik releases only these to reseek, see oidc-providers.yaml
            scopes = ["openid" "profile"];
            # authentik admits exactly these three groups to the app
            role_mapping = {
              administrator = ["sysadmin"];
              readwrite = ["arr_users"];
              readonly = ["local_users"];
            };
          };
        };
      };
    };

    # pin the uid: NFS squashes on uid, not name
    users.users.${config.services.reseek.user}.uid = 968;

    services.reseek = {
      enable = true;
      group = config.lab.media.group;
      environmentFile = config.sops.templates."reseek.env".path;
      extraConfigFiles = [config.sops.templates."reseek-oidc.toml".path];
      settings = {
        shares.directories = [music];
        # sidecars and analysis files that aren't music, regexes on the full local path
        shares.filters = [
          "\\.DS_Store$"
          "(^|/)\\._"
          "Thumbs\\.db$"
          "\\.asd$"
          "\\.json$"
          # picard's saved session at the share root
          "^${lib.escapeRegex music}/picard\\.mbps\\.gz$"
        ];
        directories = {
          downloads = "${media}/soulseek/downloads";
          incomplete = "${media}/soulseek/incomplete";
        };
        # the share index is restored from the last scan at start, and the library is on NFS,
        # whose changes made on the store send no notification
        flags.force_share_scan = true;
        soulseek = {
          listen_port = cfg.reseek.soulseekPort;
          # the VPN provider forwards the port, there is no router to ask
          port_mapping = false;
        };
        web = {
          # caddy on the edge hosts ends TLS
          https.disabled = true;
          external_url = "https://${host}";
          # caddy dials from its own box, and its X-Forwarded-Proto is what marks cookies Secure
          trusted_proxies = map (ip: "${ip}/32") topo.edgeHostIps;
          # the local login stays next to oidc until oidc is proven
          authentication.username = "admin";
        };
      };
    };

    lab.topology.routes = [
      {
        inherit host;
        title = "reseek";
        port = webPort;
        # the netns port is DNAT'd and scoped by accessibleFrom, not the input firewall
        openFirewall = false;
        # reseek signs users in itself through authentik's oidc, so no forward_auth
        middlewares = ["lan_only"];
      }
    ];

    vpnNamespaces.${vpnNs} = {
      openVPNPorts = [
        {
          port = cfg.reseek.soulseekPort;
          protocol = "tcp";
        }
      ];
      portMappings = lib.optional cfg.lanProxy {
        from = webPort;
        to = webPort;
        protocol = "tcp";
      };
      # oidc discovery and token calls reach authentik through the edge over the LAN instead
      # of leaving through the tunnel and coming back in at the WAN address
      allowedEgress = [topo.edgeEndpointIp];
    };

    # the netns resolves through the VPN's public dns, which answers the WAN address for the
    # auth host. this is the site dns answer, and the netns reads the host's /etc/hosts
    networking.hosts.${topo.edgeEndpointIp} = [authHost];

    systemd.services.reseek = {
      # vpnConfinement already binds to the wg unit, `requires` is a redundant fail-closed guard
      requires = ["${vpnNs}.service"];
      vpnConfinement = {
        enable = true;
        vpnNamespace = vpnNs;
      };
      # don't race the automount and scan the empty mountpoint underneath
      unitConfig.RequiresMountsFor = [media music];
      # group-writable downloads for the rest of the media group, the module sets 0027
      serviceConfig.UMask = lib.mkForce "0002";
    };
  };
}
