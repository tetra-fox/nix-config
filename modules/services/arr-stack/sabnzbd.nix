{
  config,
  lib,
  pkgs,
  ...
}: let
  siteData = config.lab.site.dataDir;
  cfg = config.lab.arrStack;
  mediaGroup = config.lab.media.group;
  sabnzbdStateDir = "${lib.removePrefix "/var/lib/" siteData}/sabnzbd";
  hostVethIp = config.vpnNamespaces.wg.bridgeAddress;

  # under the state dir so the sabnzbd user (which runs preStart) can write it
  serversIni = "/var/lib/${sabnzbdStateDir}/.servers-rendered.ini";

  # turn the JSON array of server objects into sabnzbd's [servers] ini section
  # create the file 0600 before writing, rather than letting `>` create it 0644 and
  # chmod'ing after: the contents are the usenet provider username and password, and the
  # after-the-fact chmod leaves them world-readable for the length of the write on first
  # render. later runs truncate an existing 0600 file, so only the first was exposed.
  renderServersCmd = ''
    install -m 0600 /dev/null ${serversIni}
    {
      echo "[servers]"
      ${lib.getExe pkgs.jq} -r '.[] | "[[\(.host)]]", (to_entries[] | "\(.key) = \(.value)")' \
        ${config.sops.secrets."apps/sabnzbd_servers".path}
    } > ${serversIni}
  '';
in {
  config = {
    sops.secrets = {
      "apps/sabnzbd_api_key" = {};
      "apps/sabnzbd_nzb_key" = {};
      # JSON array of server objects mirroring sabnzbd's server config keys verbatim,
      # edit this secret to add/remove a server with no nix change. e.g.:
      #   [{"host":"news.example.com","port":563,"ssl":1,"ssl_verify":2,
      #     "username":"<u>","password":"<p>","connections":50,"priority":0}]
      "apps/sabnzbd_servers" = {owner = "sabnzbd";};
    };

    sops.templates."sabnzbd-secrets.ini" = {
      owner = "sabnzbd";
      content = ''
        [misc]
        api_key = ${config.sops.placeholder."apps/sabnzbd_api_key"}
        nzb_key = ${config.sops.placeholder."apps/sabnzbd_nzb_key"}
      '';
    };

    # mkBefore so the servers ini is rendered before config_merge.py reads secretFiles,
    # which would fail on the missing file. in sabnzbd's own preStart so it runs as the
    # sabnzbd user, where the sops secret is readable
    systemd.services.sabnzbd.preStart = lib.mkBefore renderServersCmd;

    # the upstream sabnzbd module sets no hardening at all, which leaves the service that
    # parses untrusted usenet content and shells out to par2/unrar running with the full
    # ambient set. ProtectSystem is "full" rather than "strict" because sabnzbd writes to
    # its state dir and the media paths; strict would need every one of those enumerated.
    systemd.services.sabnzbd.serviceConfig = {
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "full";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      ProtectProc = "invisible";
      RestrictSUIDSGID = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      LockPersonality = true;
      CapabilityBoundingSet = "";
      SystemCallArchitectures = "native";
    };

    # pin the uid: NFS squashes on uid, not name
    users.users.sabnzbd.uid = 992;

    # the arrs live in the vpn netns and reach sabnzbd at the veth bridge address, so
    # they need an explicit accept now that openFirewall no longer opens 8080 wholesale
    networking.firewall.extraInputRules = ''
      ip saddr ${config.vpnNamespaces.wg.namespaceAddress} tcp dport ${toString config.services.sabnzbd.settings.misc.port} accept
    '';

    services.sabnzbd = {
      enable = true;
      group = mediaGroup;
      stateDir = sabnzbdStateDir;
      allowConfigWrite = true;
      # false: openFirewall opens 8080 on every interface from any source, which skips
      # caddy's lan_only/forward_auth. the route below carries openFirewall instead, so
      # _route-firewall.nix admits only the site's edge IPs, and the netns rule covers
      # the arrs reaching sabnzbd over the veth bridge.
      openFirewall = false;
      secretFiles = [
        config.sops.templates."sabnzbd-secrets.ini".path
        serversIni
      ];

      settings = {
        misc = {
          host = "::";
          port = 8080;
          cache_limit = "1G";
          web_dir = "Glitter";
          permissions = "775";
          language = "en";
          inet_exposure = "none";
          queue_limit = 20;
          bandwidth_perc = 100;
          download_dir = "${cfg.nzbPath}/.incomplete";
          complete_dir = cfg.nzbPath;
          download_free = "1G";
          complete_free = "1G";
          log_dir = "logs";
          admin_dir = "admin";
          host_whitelist = lib.concatStringsSep "," (
            [config.networking.hostName "${config.networking.hostName}.local" hostVethIp]
            ++ cfg.sabnzbdHostWhitelist
          );
        };

        logging = {
          log_level = 1;
          max_log_size = 5242880;
          log_backups = 5;
        };

        categories = {
          "*" = {
            name = "*";
            order = 0;
            pp = 3;
            script = "None";
            dir = "";
            priority = 0;
          };
          # empty dir on purpose: downloads land in complete_dir and the arrs move them
          # to the library, so a per-category subdir buys nothing
          radarr = {
            name = "radarr";
            order = 6;
            pp = "";
            script = "Default";
            dir = "";
            priority = -100; # sabnzbd "force" priority
          };
          sonarr = {
            name = "sonarr";
            order = 5;
            pp = "";
            script = "Default";
            dir = "";
            priority = -100;
          };
        };
      };
    };
  };
}
