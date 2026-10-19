{
  config,
  lib,
  ...
}: let
  cfg = config.lab.arrStack;
  vpnNs = "wg";
  webPort = config.services.slskd.settings.web.port;
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
        shares.directories = [];
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
      # group-writable downloads for the rest of the media group
      serviceConfig.UMask = "0002";
    };
  };
}
