{
  config,
  lib,
  siteData,
  ...
}: let
  cfg = config.lab.arrStack;
  sabnzbdStateDir = "${lib.removePrefix "/var/lib/" siteData}/sabnzbd";
  hostVethIp = config.vpnNamespaces.wg.bridgeAddress;
in {
  config = {
    sops.secrets = {
      "apps/sabnzbd_api_key" = {};
      "apps/sabnzbd_nzb_key" = {};
      # one frugalusenet cred pair reused across all 3 frugal endpoints
      "apps/sabnzbd_fun_username" = {};
      "apps/sabnzbd_fun_password" = {};
      # usenetexpress block account (different backbone) for gap-fills
      "apps/sabnzbd_une_username" = {};
      "apps/sabnzbd_une_password" = {};
    };

    sops.templates."sabnzbd-secrets.ini" = {
      owner = "sabnzbd";
      content = let
        user = config.sops.placeholder."apps/sabnzbd_fun_username";
        pass = config.sops.placeholder."apps/sabnzbd_fun_password";
        uneUser = config.sops.placeholder."apps/sabnzbd_une_username";
        unePass = config.sops.placeholder."apps/sabnzbd_une_password";
        # host -> (user, pass). frugal endpoints share one cred pair; UNE has its own.
        servers = {
          "newswest.frugalusenet.com" = {
            u = user;
            p = pass;
          };
          "news.frugalusenet.com" = {
            u = user;
            p = pass;
          };
          "bonus.frugalusenet.com" = {
            u = user;
            p = pass;
          };
          # TODO: replace with the real UNE block hostname once purchased
          "news.usenetexpress.com" = {
            u = uneUser;
            p = unePass;
          };
        };
        mkServer = host: cred: ''
          [[${host}]]
          username = ${cred.u}
          password = ${cred.p}'';
      in ''
        [misc]
        api_key = ${config.sops.placeholder."apps/sabnzbd_api_key"}
        nzb_key = ${config.sops.placeholder."apps/sabnzbd_nzb_key"}

        [servers]
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList mkServer servers)}
      '';
    };

    services.sabnzbd = {
      enable = true;
      group = cfg.mediaGroup;
      stateDir = sabnzbdStateDir;
      allowConfigWrite = true;
      openFirewall = true; # opens settings.misc.port (8080)
      secretFiles = [config.sops.templates."sabnzbd-secrets.ini".path];

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
          # netns clients reach sabnzbd via http://${hostVethIp}:8080; extra entries
          # (e.g. the public hostname caddy proxies under) come from lab.arrStack.sabnzbdHostWhitelist
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
          radarr = {
            name = "radarr";
            order = 6;
            pp = "";
            script = "Default";
            dir = "radarr";
            priority = -100; # sabnzbd "force" priority
          };
          sonarr = {
            name = "sonarr";
            order = 5;
            pp = "";
            script = "Default";
            dir = "sonarr";
            priority = -100;
          };
        };

        servers = let
          mkUsenetProvider = host: priority: connections: {
            name = host;
            displayname = host;
            inherit host;
            port = 563;
            inherit connections;
            ssl = true;
            ssl_verify = "strict";
            inherit priority;
          };
        in {
          # sabnzbd clamps priority to a 0-99 range; 99 is the lowest (last-tried).
          # keep all 3 frugal endpoints above UNE so the block is only gap-fill.
          "newswest.frugalusenet.com" = mkUsenetProvider "newswest.frugalusenet.com" 0 100;
          "news.frugalusenet.com" = mkUsenetProvider "news.frugalusenet.com" 20 100;
          "bonus.frugalusenet.com" = mkUsenetProvider "bonus.frugalusenet.com" 40 50;
          # usenetexpress block at 99 (the floor) so every frugal endpoint is tried
          # first and the block only spends data on gap-fills.
          "news.usenetexpress.com" = mkUsenetProvider "news.usenetexpress.com" 99 50;
        };
      };
    };
  };
}
