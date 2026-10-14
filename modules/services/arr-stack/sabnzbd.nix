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

  # under the state dir so the sabnzbd user can write it from preStart
  serversIni = "/var/lib/${sabnzbdStateDir}/.servers-rendered.ini";

  # created 0600 before writing, it holds the usenet credentials
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
      # json array of objects keyed like sabnzbd's server config, e.g.
      #   [{"host":"news.example.com","port":563,"ssl":1,"username":"<u>","password":"<p>"}]
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

    # mkBefore: config_merge.py fails if a secretFile is missing
    systemd.services.sabnzbd.preStart = lib.mkBefore renderServersCmd;

    # upstream sets no hardening. "full" not "strict": strict would need every media
    # path enumerated
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

    # the arrs reach sabnzbd from the netns over the veth bridge
    networking.firewall.extraInputRules = ''
      ip saddr ${config.vpnNamespaces.wg.namespaceAddress} tcp dport ${toString config.services.sabnzbd.settings.misc.port} accept
    '';

    services.sabnzbd = {
      enable = true;
      group = mediaGroup;
      stateDir = sabnzbdStateDir;
      allowConfigWrite = true;
      # would open 8080 to any source. the caddy route opens it to the edge hosts instead
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
          # empty dir: the arrs move downloads out of complete_dir anyway
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
