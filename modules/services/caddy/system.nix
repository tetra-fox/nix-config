{
  config,
  lib,
  modules,
  pkgs,
  nixosConfigurations,
  topo,
  caps,
  ...
}: let
  siteData = config.lab.site.dataDir;

  # the site's authentik outpost, used by forward_auth routes. loopback if authentik runs on
  # this box, else the derived auth-server address. null when the site has no authentik
  # (fairlane), which is what makes those sites lan-only by construction.
  authOutpost =
    if (config.lab.authentik.enable or false)
    then "http://127.0.0.1:${toString config.lab.authentik.port}"
    else if topo.authServerIp != null
    then "http://${topo.authServerIp}:${toString topo.authServerPort}"
    else null;

  anyForwardAuth = lib.any (r: lib.elem "forward_auth" r.middlewares) topo.routesInSite;

  # middleware -> caddy snippet name, emitted inside a route{} block so they run in order:
  # lan_only aborts non-LAN first, then forward_auth (the authentik snippet) gates.
  mwSnippet = {
    lan_only = "lan_only";
    forward_auth = "authentik";
  };

  # render one reverse-proxy vhost per same-site route. the engine resolved each route's upstream
  # (ipOf the declaring host + its port), so this only emits Caddy syntax. vhosts sorted by host
  # for a stable render (no diff churn when a host reorders its routes).
  renderRoute = r: let
    bodyBlock =
      if r.maxBodySize != null
      then "\n\trequest_body {\n\t\tmax_size ${r.maxBodySize}\n\t}"
      else "";
    upstream =
      if r.scheme == "https"
      then "https://${r.upstream}"
      else r.upstream;
    proxy =
      if r.middlewares == []
      then "\treverse_proxy ${upstream}"
      else
        "\troute {\n"
        + lib.concatMapStrings (m: "\t\timport ${mwSnippet.${m}}\n") r.middlewares
        + "\t\treverse_proxy ${upstream}\n\t}";
  in ''
    ${r.host} {
    	import log${bodyBlock}
    ${proxy}
    }
  '';
  renderedRoutes =
    lib.concatMapStringsSep "\n"
    renderRoute
    (lib.sort (a: b: a.host < b.host) topo.routesInSite);

  # generic edge preamble: the reusable snippets every site imports + the ACME cert issuer. no
  # vhosts here -- the resolvable ones come from renderedRoutes, the site-specific ones from
  # lab.caddy.staticTail.
  preamble =
    ''
      (lan_only) {
      	@notlan not remote_ip private_ranges
      	abort @notlan
      }

      # apache-style access log (transform-encoder plugin), imported by every vhost so fail2ban's
      # simple-regex filter matches it. caddy's default JSON is harder to write a filter against.
      (log) {
      	log {
      		output file /var/log/caddy/access.log
      		format transform "{common_log}"
      	}
      }
    ''
    # only when the site has an outpost. trusted_proxies lets it trust caddy's X-Forwarded-*
    # so it resolves the app by the original Host; copy_headers passes identity to the backend.
    # no Authorization: the arrs skip auth for local addresses (all traffic is lan_only), so
    # nothing injects basic-auth
    + lib.optionalString (authOutpost != null) ''

      (authentik) {
      	reverse_proxy /outpost.goauthentik.io/* ${authOutpost}
      	forward_auth ${authOutpost} {
      		uri /outpost.goauthentik.io/auth/caddy
      		copy_headers X-Authentik-Username X-Authentik-Groups X-Authentik-Email X-Authentik-Name X-Authentik-Uid X-Authentik-Jwt X-Authentik-Meta-Jwks X-Authentik-Meta-Outpost X-Authentik-Meta-Provider X-Authentik-Meta-App X-Authentik-Meta-Version
      		trusted_proxies private_ranges
      	}
      }
    ''
    + "\n"
    + config.lab.caddy.certIssuer;
  renderedCaddyfile = pkgs.writeText "Caddyfile" (
    preamble + "\n" + renderedRoutes + "\n" + config.lab.caddy.staticTail
  );

  ha = config.lab.caddy.ha;
  # peers are the other edge hosts' server-VLAN IPs (hostIp, not internalIp).
  selfServerIp = config.lab.site.hostIp;
  allEdgeServerIps =
    lib.sort (a: b: a < b)
    (lib.filter (ip: ip != null)
      (map (name: nixosConfigurations.${name}.config.lab.site.hostIp or null)
        (topo.hostsProviding caps.edge.name)));
  otherEdgeServerIps = lib.filter (ip: ip != selfServerIp) allEdgeServerIps;
  selfEdgeIdx = lib.lists.findFirstIndex (i: i == selfServerIp) 0 allEdgeServerIps;
in {
  imports = [modules.services.vrrp.system];

  options.lab.caddy = {
    # the acme issuer, a raw Caddyfile global-options block appended to the preamble. the
    # default does dns-01 via cloudflare, whose token rides in through environmentSecrets;
    # a site on another dns provider overrides both (and needs a package built with the
    # matching dns plugin).
    certIssuer = lib.mkOption {
      type = lib.types.lines;
      default = ''
        {
        	cert_issuer acme {
        		dns cloudflare {$CF_TOKEN}
        		resolvers 1.1.1.1 8.8.8.8
        	}
        }
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/caddy-dns/cloudflare@v0.2.4"
          "github.com/caddyserver/transform-encoder@v0.0.0-20260423033309-ba4124974830"
        ];
        hash = "sha256-mF0V4puEMkQKyhx5NytbWB5ygH4Bkun+7yV7lecxhDI=";
      };
      description = "the caddy build. the default carries the cloudflare dns plugin (for the default certIssuer) and transform-encoder (fail2ban's log format).";
    };

    environmentSecrets = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {CF_TOKEN = "net/cf_token";};
      description = "env var name -> sops secret name, rendered into caddy's EnvironmentFile. the default carries the cloudflare acme token.";
    };

    # site-specific Caddyfile blocks appended after the rendered routes: the root vhost and
    # appliances with no capability publisher (HAOS, proxmox). everything derivable is a route.
    staticTail = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "host-specific Caddyfile blocks appended after the engine-rendered route vhosts";
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

      virtualRouterId = lib.mkOption {
        type = lib.types.int;
        default = 52;
        description = "VRRP router id for the edge VIP, unique per L2 segment (see lab.vrrp.virtualRouterId).";
      };
    };
  };

  config = {
    lab.topology.provides = [caps.edge.name];

    services.caddy = {
      enable = true;
      dataDir = "${siteData}/caddy";
      package = config.lab.caddy.package;
      configFile = renderedCaddyfile;
    };

    sops.secrets = lib.mapAttrs' (_: secret: lib.nameValuePair secret {}) config.lab.caddy.environmentSecrets;
    sops.templates."caddy.env" = {
      content =
        lib.concatStrings
        (lib.mapAttrsToList (var: secret: "${var}=${config.sops.placeholder.${secret}}\n")
          config.lab.caddy.environmentSecrets);
      owner = "caddy";
      group = "caddy";
    };

    systemd = {
      services = {
        caddy = {
          serviceConfig.EnvironmentFile = [
            config.sops.templates."caddy.env".path
          ];
        };

        fail2ban = {
          # the caddy-status jail bans on 401/403/429 only (see caddy-status.conf), not any 4xx
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
      # heartbeat and VIP both on the server VLAN (clients and the router reach the VIP there)
      vrrpInterface = config.lab.site.serverInterface;
      vipInterface = config.lab.site.serverInterface;
      inherit (ha) virtualRouterId;
      priorityIndex = selfEdgeIdx;
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
      {
        assertion = !anyForwardAuth || authOutpost != null;
        message = "a route requests the forward_auth middleware but this site has no authentik outpost (no host provides caps.authServer); deploy authentik or drop forward_auth from the route.";
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
      # the LAN ranges plus loopback and the rest of private space; banning any of it is never right
      ignoreIP =
        config.lab.net.privateRanges
        ++ [
          "127.0.0.0/8"
          "::1/128"
          "172.16.0.0/12"
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
      # instaban known-probe paths (wp-login, .env, .git, phpunit, shells). the filter matches on
      # path, not status, so it fires on the 404s these generate. maxretry=1 because a single hit is
      # unambiguous; 24h base ban (the jail default is 1h) since there's no legit reason to be here.
      jails.caddy-probe.settings = {
        enabled = true;
        filter = "caddy-probe";
        logpath = "/var/log/caddy/access.log";
        backend = "auto";
        findtime = "10m";
        maxretry = 1;
        bantime = "24h";
      };
      daemonSettings.Definition.dbfile = "${siteData}/fail2ban/fail2ban.sqlite3";
    };

    environment.etc = {
      "fail2ban/filter.d/caddy-status.conf".source = ./files/caddy-status.conf;
      "fail2ban/filter.d/caddy-probe.conf".source = ./files/caddy-probe.conf;
    };
  };
}
