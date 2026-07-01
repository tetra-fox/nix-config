{
  config,
  lib,
  modules,
  fleet,
  pkgs,
  siteData,
  nixosConfigurations,
  ...
}: let
  topo = import fleet.topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };
  defaultStatsUpstream =
    if (config.lab.monitoring.server.enable or false)
    then "127.0.0.1:3000"
    else if topo.serverIp != null
    then "${topo.serverIp}:3000"
    else "127.0.0.1:3000";

  defaultAuthUpstream =
    if (config.lab.authentik.enable or false)
    then "127.0.0.1:9000"
    else if topo.authServerIp != null
    then "${topo.authServerIp}:9000"
    else "127.0.0.1:9000";

  mediaIsLocal = config.services.jellyfin.enable;
  mediaHostAddr =
    if mediaIsLocal
    then "127.0.0.1"
    else if topo.mediaHostIp != null
    then topo.mediaHostIp
    else "127.0.0.1";

  ha = config.lab.caddy.ha;
  # peers are the other edge hosts' server-VLAN IPs (hostIp, not internalIp).
  selfServerIp = config.lab.site.hostIp;
  allEdgeServerIps =
    lib.sort (a: b: a < b)
    (lib.filter (ip: ip != null)
      (map (name: nixosConfigurations.${name}.config.lab.site.hostIp or null)
        (topo.hostsProviding "edge")));
  otherEdgeServerIps = lib.filter (ip: ip != selfServerIp) allEdgeServerIps;
  selfEdgeIdx = lib.lists.findFirstIndex (i: i == selfServerIp) 0 allEdgeServerIps;
in {
  imports = [modules.services.vrrp.system];

  options.lab.caddy = {
    caddyfile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
    };

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
    lab.topology.provides = ["edge"];

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

    systemd = {
      services = {
        caddy = {
          serviceConfig.EnvironmentFile = [
            config.sops.templates."caddy.env".path
          ];

          environment = {
            STATS_UPSTREAM = config.lab.caddy.statsUpstream;
            AUTH_UPSTREAM = config.lab.caddy.authUpstream;
            JELLYFIN_UPSTREAM = config.lab.caddy.jellyfinUpstream;
            NP_UPSTREAM = config.lab.caddy.npUpstream;
          };
        };

        fail2ban = {
          # StateDirectory is relative to /var/lib; must resolve to the same dir as the fail2ban dbfile
          serviceConfig.StateDirectory = lib.mkForce "${lib.removePrefix "/var/lib/" siteData}/fail2ban";

          after = ["caddy.service"];
          wants = ["caddy.service"];
        };
      };

      # upstream only creates dataDir when it's the default /var/lib/caddy; overriding to
      # siteData means we create it ourselves or the ReadWritePaths bind-mount fails 226/NAMESPACE.
      # pre-create access.log too: fail2ban's caddy-status jail won't start with its logpath missing.
      tmpfiles.rules = [
        "d ${config.services.caddy.dataDir} 0700 caddy caddy -"
        # own the log dir before the file rule, else tmpfiles creates the parent root-owned and caddy can't rotate
        "d /var/log/caddy 0750 caddy caddy -"
        "f /var/log/caddy/access.log 0644 caddy caddy -"
      ];
    };

    networking.firewall.allowedTCPPorts = [80 443];

    # caddy binds :80/:443 on all interfaces, so it catches VIP traffic with no ip_nonlocal_bind.
    lab.vrrp = lib.mkIf ha.enable {
      enable = true;
      inherit (ha) vip;
      vrrpInterface = "ens18";
      vipInterface = "ens18";
      virtualRouterId = 52; # unique per L2 segment
      priority = 110 - (selfEdgeIdx * 5);
      unicastSrcIp = selfServerIp;
      unicastPeers = otherEdgeServerIps;
      instanceName = "caddyvip";
      healthCheck = {
        name = "chk_caddy";
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
        maxtime = "168h";
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
      daemonSettings.Definition.dbfile = "${siteData}/fail2ban/fail2ban.sqlite3";
    };

    environment.etc."fail2ban/filter.d/caddy-status.conf".source = ./files/caddy-status.conf;
  };
}
