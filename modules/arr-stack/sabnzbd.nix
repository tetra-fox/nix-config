{
  config,
  lib,
  pkgs,
  siteData,
  ...
}: let
  cfg = config.lab.arrStack;
  sabnzbdStateDir = "${lib.removePrefix "/var/lib/" siteData}/sabnzbd";
  hostVethIp = config.vpnNamespaces.wg.bridgeAddress;

  # the rendered [servers] ini, generated from the apps/sabnzbd_servers JSON secret
  # and listed in secretFiles so sabnzbd's config_merge picks it up. it lives under
  # the sabnzbd state dir (writable by the sabnzbd user that runs preStart).
  serversIni = "/var/lib/${sabnzbdStateDir}/.servers-rendered.ini";

  # turn the JSON array of server objects into sabnzbd's [servers] ini section.
  # each object is a full sabnzbd server config: any key sabnzbd accepts works
  # (host, port, ssl, ssl_verify, username, password, connections, priority, ...).
  # section header is [[<host>]]; jq emits "key = value" per field.
  renderServersCmd = ''
    {
      echo "[servers]"
      ${lib.getExe pkgs.jq} -r '.[] | "[[\(.host)]]", (to_entries[] | "\(.key) = \(.value)")' \
        ${config.sops.secrets."apps/sabnzbd_servers".path}
    } > ${serversIni}
    chmod 0600 ${serversIni}
  '';
in {
  config = {
    sops.secrets = {
      "apps/sabnzbd_api_key" = {};
      "apps/sabnzbd_nzb_key" = {};
      # one JSON array of full sabnzbd server objects. add/remove/configure a server
      # by editing this one secret -- no nix change needed. each object mirrors
      # sabnzbd's server config keys verbatim, e.g.:
      #   [
      #     {"host":"newswest.frugalusenet.com","port":563,"ssl":1,"ssl_verify":2,
      #      "username":"<u>","password":"<p>","connections":100,"priority":0},
      #     {"host":"news.usenetexpress.com","port":563,"ssl":1,"ssl_verify":2,
      #      "username":"<u>","password":"<p>","connections":50,"priority":99}
      #   ]
      # ssl/ssl_verify/enable use sabnzbd's ints (ssl=1, ssl_verify=2=strict).
      # priority: lower is preferred; sabnzbd clamps to 0-99 (99 = last/fill).
      "apps/sabnzbd_servers" = {owner = "sabnzbd";};
    };

    # api_key + nzb_key still go via a sops template (simple scalar interpolation).
    # the servers section is rendered separately at runtime from the JSON secret.
    sops.templates."sabnzbd-secrets.ini" = {
      owner = "sabnzbd";
      content = ''
        [misc]
        api_key = ${config.sops.placeholder."apps/sabnzbd_api_key"}
        nzb_key = ${config.sops.placeholder."apps/sabnzbd_nzb_key"}
      '';
    };

    # render the [servers] ini as the FIRST thing in sabnzbd's own preStart, before
    # its config_merge.py reads secretFiles (which would fail on a missing file).
    # doing it in the same script -- rather than a separate ordered service -- means
    # there's no inter-unit ordering to get wrong: it runs as the sabnzbd user where
    # the sops secret is already decrypted and readable. mkBefore prepends it.
    systemd.services.sabnzbd.preStart = lib.mkBefore renderServersCmd;

    # pin the uid so it's identical across boxes; the NFS share squashes on uid, not
    # name. upstream services.sabnzbd creates the user but auto-allocates the uid.
    users.users.sabnzbd.uid = 992;

    services.sabnzbd = {
      enable = true;
      group = cfg.mediaGroup;
      stateDir = sabnzbdStateDir;
      allowConfigWrite = true;
      openFirewall = true; # opens settings.misc.port (8080)
      # both files get merged into the live config: the scalar secrets template,
      # and the runtime-rendered [servers] section.
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
        # servers are no longer defined here; they come from the apps/sabnzbd_servers
        # JSON secret rendered into serversIni above.
      };
    };
  };
}
