{
  config,
  lib,
  modules,
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
  topo = import modules.meta.lib.site-topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };
  defaultStatsUpstream =
    if (config.lab.monitoring.server.enable or false)
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

  ha = config.lab.caddy.ha;
  # the VIP lives on the SERVER VLAN (ens18) -- the router forwards 443/80 to it and the
  # AdGuard wildcard points at it, so it must be reachable from off the internal fabric.
  # peers are the other edge hosts' server-VLAN IPs (hostIp, not the derive's internalIp).
  selfServerIp = config.lab.site.hostIp;
  allEdgeServerIps =
    lib.sort (a: b: a < b)
    (lib.filter (ip: ip != null)
      (map (name: nixosConfigurations.${name}.config.lab.site.hostIp or null)
        (topo.hostsWhere topo.isEdgeHost)));
  otherEdgeServerIps = lib.filter (ip: ip != selfServerIp) allEdgeServerIps;
  selfEdgeIdx = lib.lists.findFirstIndex (i: i == selfServerIp) 0 allEdgeServerIps;
in {
  imports = [modules.meta.vrrp.system];

  options.lab.caddy = {
    caddyfile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
    };

    # high-availability ingress: run keepalived and float a VIP across the edge hosts. caddy
    # is stateless (every node serves identical derived config), so unlike the db cluster
    # there's no leader/HAProxy -- the VIP just needs to land on a live caddy. every edge host
    # declares the same vip; the router forwards 443/80 to it and the AdGuard wildcard points
    # at it. the site-topology edgeEndpointIp derive returns the vip when HA is live.
    ha = {
      enable = lib.mkEnableOption "run keepalived and join the edge VIP on this host";

      vip = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          the floating virtual IP keepalived parks on a live edge host, on the server VLAN
          (the router forwards 443/80 here). every edge host declares the same value.
        '';
      };
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
      # pin the log dir's ownership to caddy before the access.log file rule, so on a fresh
      # box tmpfiles doesn't create the parent root-owned (leaving caddy unable to rotate)
      "d /var/log/caddy 0750 caddy caddy -"
      "f /var/log/caddy/access.log 0644 caddy caddy -"
    ];

    networking.firewall.allowedTCPPorts = [80 443];

    # edge HA: float the VIP across the edge hosts. the keepalived scaffolding is shared via
    # modules.meta.vrrp.system (db + dns use it too); this only supplies the edge-specific values.
    # caddy listens on all interfaces :80/:443 (no explicit bind), so traffic to the VIP is
    # caught automatically -- no ip_nonlocal_bind needed. unlike db/dns, edge runs both the VRRP
    # heartbeat AND the VIP on ens18 (the server VLAN), since that's where the router forwards
    # 443/80 and there's no separate isolated path for edge.
    lab.vrrp = lib.mkIf ha.enable {
      enable = true;
      vip = ha.vip;
      vrrpInterface = "ens18";
      vipInterface = "ens18";
      virtualRouterId = 52; # 51 = db, 53 = dns; unique per L2 segment
      priority = 110 - (selfEdgeIdx * 5); # lowest-IP edge host is the default holder
      unicastSrcIp = selfServerIp;
      unicastPeers = otherEdgeServerIps;
      instanceName = "caddyvip";
      healthCheck = {
        name = "chk_caddy";
        # caddy down -> drop the VIP so the other node takes 443/80. pgrep needs no privileges.
        script = "${pkgs.procps}/bin/pgrep -x caddy";
      };
    };

    assertions = [
      {
        assertion = !ha.enable || ha.vip != null;
        message = "lab.caddy.ha.enable requires lab.caddy.ha.vip (the floating ingress endpoint).";
      }
    ];

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

    environment.etc."fail2ban/filter.d/caddy-status.conf".source = ./files/caddy-status.conf;
  };
}
