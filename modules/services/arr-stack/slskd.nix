{
  config,
  lib,
  ...
}: let
  cfg = config.lab.arrStack;
  vpnNs = "wg";
  webPort = config.services.slskd.settings.web.port;
  media = config.lab.storage.mounts.media.mountpoint;
  music = config.lab.storage.mounts.music.mountpoint;
in {
  options.lab.arrStack.slskd = {
    enable = lib.mkEnableOption "slskd, a soulseek client with a web ui, in the vpn netns";

    soulseekPort = lib.mkOption {
      type = lib.types.port;
      description = ''
        slskd's soulseek listen port, a second port forwarded by the VPN provider. without
        it peers that are also firewalled can't reach this client at all
      '';
    };
  };

  config = lib.mkIf cfg.slskd.enable {
    sops.secrets = {
      "slskd/username" = {};
      "slskd/password" = {};
    };

    # default root 0400: systemd reads EnvironmentFile as root
    sops.templates."slskd.env".content = ''
      SLSKD_SLSK_USERNAME=${config.sops.placeholder."slskd/username"}
      SLSKD_SLSK_PASSWORD=${config.sops.placeholder."slskd/password"}
    '';

    # pin the uid: NFS squashes on uid, not name
    users.users.slskd.uid = 970;

    services.slskd = {
      enable = true;
      group = config.lab.media.group;
      environmentFile = config.sops.templates."slskd.env".path;
      settings = {
        # the upstream unit mounts shares read-only
        shares.directories = [music];
        # sidecars and analysis files that aren't music
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
          downloads = "${media}/slskd/downloads";
          incomplete = "${media}/slskd/incomplete";
        };
        # upstream leaves it unset, and then slskd restores its cached share list on start
        # instead of picking up library changes
        flags.force_share_scan = true;
        soulseek.listen_port = cfg.slskd.soulseekPort;
        # same model as the arrs: only the edge hosts can reach the web port (accessibleFrom),
        # and caddy's lan_only and forward_auth are the login
        web.authentication.disabled = true;
      };
    };

    vpnNamespaces.${vpnNs} = {
      openVPNPorts = [
        {
          port = cfg.slskd.soulseekPort;
          protocol = "tcp";
        }
      ];
      portMappings = lib.optional cfg.lanProxy {
        from = webPort;
        to = webPort;
        protocol = "tcp";
      };
    };

    systemd.services.slskd = {
      # vpnConfinement already binds to the wg unit, `requires` is a redundant fail-closed guard
      requires = ["${vpnNs}.service"];
      vpnConfinement = {
        enable = true;
        vpnNamespace = vpnNs;
      };
      # don't race the automount and scan the empty mountpoint underneath
      unitConfig.RequiresMountsFor = [media music];
      # group-writable downloads for the rest of the media group
      serviceConfig.UMask = "0002";
    };
  };
}
