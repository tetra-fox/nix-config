{
  config,
  lib,
  pkgs,
  siteData,
  nixosConfigurations,
  ...
}: let
  # grafana lives on the site's monitoring server. caddy on any site host should
  # reverse-proxy stats.<site> to that server. derive its address from the same
  # site-topology used by the monitoring module: loopback when this host IS the
  # server (grafana is local), else the server's IP. exposed in the Caddyfile as
  # {$STATS_UPSTREAM} so the static Caddyfile doesn't hardcode mon-01's location.
  topo = import ../monitoring/site-topology.nix {inherit lib;} {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };
  defaultStatsUpstream =
    if config.lab.monitoring.server.enable
    then "127.0.0.1:3000"
    else if topo.serverIp != null
    then "${topo.serverIp}:3000"
    else "127.0.0.1:3000"; # bootstrap fallback before a server exists

  # authentik upstream: loopback if authentik runs on this same host, else the derived
  # auth host IP. exposed as {$AUTH_UPSTREAM} so the Caddyfile doesn't hardcode it.
  defaultAuthUpstream =
    if (config.lab.authentik.enable or false)
    then "127.0.0.1:9000"
    else if topo.authServerIp != null
    then "${topo.authServerIp}:9000"
    else "127.0.0.1:9000"; # bootstrap fallback

  # jellyfin + nowplaying live on the media host. loopback if this box IS the media host
  # (jellyfin local), else the derived media host IP. {$JELLYFIN_UPSTREAM}/{$NP_UPSTREAM}.
  mediaIsLocal = config.services.jellyfin.enable;
  mediaHostAddr =
    if mediaIsLocal
    then "127.0.0.1"
    else if topo.mediaHostIp != null
    then topo.mediaHostIp
    else "127.0.0.1"; # bootstrap fallback
in {
  options.lab.caddy = {
    caddyfile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
    };

    statsUpstream = lib.mkOption {
      type = lib.types.str;
      default = defaultStatsUpstream;
      description = ''
        upstream for the stats.<site> vhost (grafana), referenced in the Caddyfile as
        {$STATS_UPSTREAM}. defaults to the site's monitoring server (loopback if this
        host is the server, else the derived <site>-mon-01 IP).
      '';
    };

    authUpstream = lib.mkOption {
      type = lib.types.str;
      default = defaultAuthUpstream;
      description = ''
        upstream for authentik (auth.<site> + the forward_auth outpost), referenced in
        the Caddyfile as {$AUTH_UPSTREAM}. defaults to the site's authentik host
        (loopback if local, else the derived auth host IP).
      '';
    };

    jellyfinUpstream = lib.mkOption {
      type = lib.types.str;
      default = "${mediaHostAddr}:8096";
      description = "upstream for jellyfin.<site> ({$JELLYFIN_UPSTREAM}); the derived media host";
    };

    npUpstream = lib.mkOption {
      type = lib.types.str;
      default = "${mediaHostAddr}:8090";
      description = "upstream for np.<site> ({$NP_UPSTREAM}); the derived media host (nowplaying)";
    };
  };

  config = {
    services.caddy = {
      enable = true;
      dataDir = "${siteData}/caddy";
      package = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/caddy-dns/cloudflare@v0.2.4"
          "github.com/caddyserver/transform-encoder@v0.0.0-20260423033309-ba4124974830"
        ];
        hash = "sha256-mF0V4puEMkQKyhx5NytbWB5ygH4Bkun+7yV7lecxhDI=";
      };
      configFile = lib.mkIf (config.lab.caddy.caddyfile != null) config.lab.caddy.caddyfile;
    };

    sops.secrets."net/cf_token" = {};
    sops.templates."caddy.env" = {
      content = "CF_TOKEN=${config.sops.placeholder."net/cf_token"}\n";
      owner = "caddy";
      group = "caddy";
    };

    systemd.services.caddy.serviceConfig.EnvironmentFile = [
      config.sops.templates."caddy.env".path
    ];

    # grafana upstream for the stats.<site> vhost, referenced as {$STATS_UPSTREAM}
    # in the Caddyfile. derived from site-topology (the site's monitoring server).
    systemd.services.caddy.environment.STATS_UPSTREAM = config.lab.caddy.statsUpstream;
    # authentik upstream ({$AUTH_UPSTREAM}); derived from site-topology (the auth host).
    systemd.services.caddy.environment.AUTH_UPSTREAM = config.lab.caddy.authUpstream;
    # jellyfin + nowplaying upstreams ({$JELLYFIN_UPSTREAM}/{$NP_UPSTREAM}); the media host.
    systemd.services.caddy.environment.JELLYFIN_UPSTREAM = config.lab.caddy.jellyfinUpstream;
    systemd.services.caddy.environment.NP_UPSTREAM = config.lab.caddy.npUpstream;

    # upstream only sets StateDirectory (which creates dataDir) when dataDir is the
    # default /var/lib/caddy; overriding it to siteData means we have to create the
    # dir ourselves, or the unit's ReadWritePaths bind-mount fails with 226/NAMESPACE.
    # also pre-create the access log: fail2ban's caddy-status jail refuses to start if
    # its logpath is missing, which it is on a fresh box before caddy's first request.
    systemd.tmpfiles.rules = [
      "d ${config.services.caddy.dataDir} 0700 caddy caddy -"
      "f /var/log/caddy/access.log 0644 caddy caddy -"
    ];

    networking.firewall.allowedTCPPorts = [80 443];

    services.fail2ban = {
      enable = true;
      bantime = "1h";
      bantime-increment = {
        enable = true;
        maxtime = "168h"; # 1 week ceiling for repeat offenders
        overalljails = true;
      };
      ignoreIP = [
        "127.0.0.0/8"
        "::1/128"
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "fc00::/7"
      ];
      jails.caddy-status.settings = {
        enabled = true;
        filter = "caddy-status";
        logpath = "/var/log/caddy/access.log";
        backend = "auto";
        findtime = "10m";
        maxretry = 5;
      };
      # state under siteData so one backup target catches it
      daemonSettings.Definition.dbfile = "${siteData}/fail2ban/fail2ban.sqlite3";
    };

    # StateDirectory is relative to /var/lib, so strip the prefix off siteData to keep it in sync with dbfile above
    systemd.services.fail2ban.serviceConfig.StateDirectory = lib.mkForce "${lib.removePrefix "/var/lib/" siteData}/fail2ban";

    # order fail2ban after caddy (its jail watches caddy's access log, pre-created above)
    systemd.services.fail2ban = {
      after = ["caddy.service"];
      wants = ["caddy.service"];
    };

    environment.etc."fail2ban/filter.d/caddy-status.conf".text = ''
      [Definition]
      failregex = ^<HOST>.*"(GET|POST|HEAD|OPTIONS|PUT|DELETE|PATCH).*" 4[0-9][0-9] [0-9]+$
      ignoreregex =
    '';
  };
}
