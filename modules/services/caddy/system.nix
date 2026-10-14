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

  # null on a site without authentik (fairlane), which keeps it lan-only
  authOutpost =
    if (config.lab.authentik.enable or false)
    then "http://127.0.0.1:${toString config.lab.authentik.port}"
    else if topo.authServerIp != null
    then "http://${topo.authServerIp}:${toString topo.authServerPort}"
    else null;

  anyForwardAuth = lib.any (r: lib.elem "forward_auth" r.middlewares) topo.routesInSite;

  # emitted inside a route{} block so they run in list order
  mwSnippet = {
    lan_only = "lan_only";
    forward_auth = "authentik";
  };

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

  preamble =
    ''
      (lan_only) {
      	@notlan not remote_ip private_ranges
      	abort @notlan
      }

      # apache-style, for fail2ban's regex filters
      (log) {
      	log {
      		# caddy's defaults keep ten 100M rolls for 90 days; fail2ban only reads the live file
      		output file /var/log/caddy/access.log {
      			roll_keep 3
      			roll_keep_for 168h
      		}
      		format transform "{common_log}"
      	}
      }
    ''
    # trusted_proxies so the outpost resolves the app by the original Host.
    # no Authorization header: the arrs skip auth for local addresses
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
  # server-VLAN IPs (hostIp), not internalIp
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
    # another dns provider overrides this, environmentSecrets and package together
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
        hash = "sha256-hWNLweb0wPIxZs+AYJl0S2T6o23BSVhgo4WJsygC3d4=";
      };
      description = "the caddy build. the default carries the cloudflare dns plugin (for the default certIssuer) and transform-encoder (fail2ban's log format).";
    };

    environmentSecrets = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {CF_TOKEN = "net/cf_token";};
      description = "env var name -> sops secret name, rendered into caddy's EnvironmentFile. the default carries the cloudflare acme token.";
    };

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
          # relative to /var/lib, must match the dbfile's dir
          serviceConfig.StateDirectory = lib.mkForce "${lib.removePrefix "/var/lib/" siteData}/fail2ban";

          after = ["caddy.service"];
          wants = ["caddy.service"];
        };
      };

      # upstream only creates the default dataDir, without it ReadWritePaths fails 226/NAMESPACE.
      # fail2ban won't start with its logpath missing
      tmpfiles.rules = [
        "d ${config.services.caddy.dataDir} 0700 caddy caddy -"
        # before the file rule, else tmpfiles makes the dir root-owned and caddy can't rotate
        "d /var/log/caddy 0750 caddy caddy -"
        "f /var/log/caddy/access.log 0644 caddy caddy -"
      ];
    };

    networking.firewall.allowedTCPPorts = [80 443];

    # caddy binds all interfaces, so the VIP needs no ip_nonlocal_bind
    lab.vrrp = lib.mkIf ha.enable {
      enable = true;
      inherit (ha) vip;
      # heartbeat on the server VLAN too, where the router reaches the VIP
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
      # all private space, not just the LAN
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
      # a single probe-path hit is unambiguous
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
