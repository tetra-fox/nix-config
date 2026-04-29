{
  config,
  lib,
  siteData,
  hostVethIp,
  ...
}: let
  cfg = config.lab.arrStack;
  sabnzbdStateDir = "${lib.removePrefix "/var/lib/" siteData}/sabnzbd";
in {
  config = {
    sops.secrets = {
      "apps/sabnzbd_api_key" = {};
      "apps/sabnzbd_nzb_key" = {};
      # frugalusenet bundle (single cred pair, used by all 3 server endpoints).
      "apps/sabnzbd_usenet_username" = {};
      "apps/sabnzbd_usenet_password" = {};
    };

    sops.templates."sabnzbd-secrets.ini" = {
      owner = "sabnzbd";
      content = let
        user = config.sops.placeholder."apps/sabnzbd_usenet_username";
        pass = config.sops.placeholder."apps/sabnzbd_usenet_password";
        servers = [
          "newswest.frugalusenet.com"
          "news.frugalusenet.com"
          "bonus.frugalusenet.com"
        ];
        mkServer = host: ''
          [[${host}]]
          username = ${user}
          password = ${pass}'';
      in ''
        [misc]
        api_key = ${config.sops.placeholder."apps/sabnzbd_api_key"}
        nzb_key = ${config.sops.placeholder."apps/sabnzbd_nzb_key"}

        [servers]
        ${lib.concatMapStringsSep "\n" mkServer servers}
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
          # sonarr/radarr in netns reach sabnzbd via http://${hostVethIp}:8080;
          host_whitelist = "${config.networking.hostName},${config.networking.hostName}.local,${hostVethIp}";
        };

        logging = {
          log_level = 1;
          max_log_size = 5242880;
          log_backups = 5;
        };

        # sonarr/radarr put completed downloads in <complete_dir>/<category>/
        # via sabnzbd's category routing.
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
          "newswest.frugalusenet.com" = mkUsenetProvider "newswest.frugalusenet.com" 0 100;
          "news.frugalusenet.com" = mkUsenetProvider "news.frugalusenet.com" 20 100;
          "bonus.frugalusenet.com" = mkUsenetProvider "bonus.frugalusenet.com" 99 50;
        };
      };
    };
  };
}
