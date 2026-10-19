{
  config,
  lib,
  pkgs,
  inputs,
  modules,
  topo,
  caps,
  ...
}: let
  siteData = config.lab.site.dataDir;
  cfg = config.lab.arrStack;
  mediaGroup = config.lab.media.group;
  arrLib = import ./lib.nix {inherit lib;};

  arrPgUser = "arr";
  arrPgPassSecret = "arr/pg_pass";

  # VPN-Confinement caps namespace names at 7 chars (used as unit + iface suffix)
  vpnNs = "wg";
  vpn = config.vpnNamespaces.${vpnNs};

  inherit (topo) dbEndpointIp;

  # local db is reached over the veth bridge
  defaultPostgresHost =
    if config.lab.postgres.server.enable
    then vpn.bridgeAddress
    else dbEndpointIp;

  arrServices = {
    sonarr = {
      port = cfg.lanProxyPorts.sonarr;
      inNetns = true;
      apiKey = {_sops = "apps/sonarr_api_key";};
      hasNixosModule = true;
      uid = 274; # pin uids: NFS squashes on uid, so they must match across boxes
    };
    radarr = {
      port = cfg.lanProxyPorts.radarr;
      inNetns = true;
      apiKey = {_sops = "apps/radarr_api_key";};
      hasNixosModule = true;
      uid = 275;
    };
    prowlarr = {
      port = cfg.lanProxyPorts.prowlarr;
      inNetns = true;
      # services.prowlarr has no environmentFiles option
      apiKey = null;
      hasNixosModule = false;
      user = "prowlarr";
      uid = 276;
    };
  };

  baseSettings = {
    auth = {
      method = "Forms";
      # caddy dials from a local address, so forward_auth stays the only login. direct
      # LAN access (api key readable via /initialize.json) is blocked by accessibleFrom
      required = "DisabledForLocalAddresses";
    };
    log.level = "info";
    postgres = {
      host = cfg.postgresHost;
      port = 5432;
      user = arrPgUser;
      password = {_sops = arrPgPassSecret;};
    };
  };

  mkServiceSettings = name: svc:
    lib.recursiveUpdate baseSettings {
      postgres = {
        main_db = "${name}-main";
        log_db = "${name}-log";
      };
      auth = lib.optionalAttrs (svc.apiKey != null) {apikey = svc.apiKey;};
    };

  allSopsRefs = lib.unique (lib.concatLists (
    lib.mapAttrsToList (n: svc: arrLib.collectSopsRefs (mkServiceSettings n svc)) arrServices
  ));

  mkEnvFileContent = name: svc: let
    prefix = lib.toUpper name;
    envVars = arrLib.mkServarrEnv (s: config.sops.placeholder.${s}) prefix (mkServiceSettings name svc);
  in
    lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}=${v}") envVars);

  arrDbs = lib.flatten (lib.mapAttrsToList (n: _: ["${n}-main" "${n}-log"]) arrServices);

  # local db only: avoids a bad-creds crash-loop while the password oneshot runs
  dbIsLocal = config.lab.postgres.server.enable;
  pgPasswordUnit = lib.optional dbIsLocal config.lab.postgres.passwordUnits.${arrPgUser};

  # vpnConfinement already binds to the wg unit, `requires` is a redundant fail-closed guard
  arrDeps = svc: {
    after = pgPasswordUnit;
    requires =
      pgPasswordUnit
      ++ lib.optional svc.inNetns "${vpnNs}.service";
    vpnConfinement = lib.optionalAttrs svc.inNetns {
      enable = true;
      vpnNamespace = vpnNs;
    };
    # servarr modules hardcode UMask 0022, which makes library dirs unwritable to the
    # rest of the media group (UnauthorizedAccessException on import)
    serviceConfig = {UMask = lib.mkForce "0002";} // arrHardening;
  };

  # mkDefault so upstream module settings win. no MemoryDenyWriteExecute: .NET and
  # python JIT
  arrHardening = lib.mapAttrs (_: lib.mkDefault) {
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

  # the arrs don't retry a failed initial db connection, they park alive ("Non-recoverable
  # failure") so Restart never fires. pg_isready does a real handshake, so haproxy accepting
  # tcp with no healthy backend still reads as not ready
  waitForDb = pkgs.writeShellScript "arr-wait-for-postgres" ''
    until ${config.lab.postgres.package}/bin/pg_isready -q -h ${cfg.postgresHost} -p 5432 -t 3; do
      sleep 2
    done
  '';

  arrDbGate.serviceConfig = {
    ExecStartPre = lib.mkBefore ["${waitForDb}"];
    TimeoutStartSec = 180;
  };

  wgConfTemplate = ''
    [Interface]
    PrivateKey = ${config.sops.placeholder."arr/wg_private_key"}
    Address = ${config.sops.placeholder."arr/wg_address"}
    DNS = 1.1.1.1

    [Peer]
    PublicKey = ${config.sops.placeholder."arr/wg_peer_public_key"}
    PresharedKey = ${config.sops.placeholder."arr/wg_preshared_key"}
    Endpoint = ${config.sops.placeholder."arr/wg_peer_endpoint"}
    AllowedIPs = 0.0.0.0/0,::/0
    PersistentKeepalive = 15
  '';
in {
  imports = [
    inputs.vpn-confinement.nixosModules.default
    ./qbittorrent.nix
    ./sabnzbd.nix
    ./slskd.nix
    ./recyclarr.nix
    ./downloadclients.nix
    ./jellyfin-notify.nix
    ./cleanup-profiles.nix
    # options only, a host running the server imports postgres.system itself
    modules.services.postgres.options
    modules.services.monitoring.registry
  ];

  options.lab.arrStack = {
    lanProxy =
      lib.mkEnableOption "DNAT host ports into the vpn netns for LAN access"
      // {default = true;};

    # read by the db host via topo.arrDbRole. static default so the cross-host read can't cycle
    dbRole = lib.mkOption {
      readOnly = true;
      default = {
        name = arrPgUser;
        passwordSecret = arrPgPassSecret;
        owns = arrDbs;
      };
    };

    torrentsPath = lib.mkOption {type = lib.types.str;};
    nzbPath = lib.mkOption {type = lib.types.str;};

    accessibleFrom = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = map (ip: "${ip}/32") topo.edgeHostIps;
      description = ''
        sources allowed to reach the namespace via portMappings. edge hosts only, so
        LAN clients can't skip caddy's lan_only and forward_auth. on-host helpers use
        the netns address and aren't affected.
      '';
    };

    postgresHost = lib.mkOption {
      type = lib.types.str;
      default = defaultPostgresHost;
      description = ''
        host the arrs connect to for postgres. defaults to the veth bridge address
        for a local db, else the site's db endpoint.
      '';
    };

    netnsSnatHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = lib.optional (!dbIsLocal && dbEndpointIp != null) dbEndpointIp;
      description = ''
        LAN IPs the arrs reach outside the tunnel, masqueraded to this host's LAN
        address via allowedEgress. defaults to the remote db's IP.
      '';
    };

    wgMtu = lib.mkOption {
      type = lib.types.int;
      default = 1320; # AirVPN
      description = "MTU applied to the wg interface after wg setconf";
    };

    lanProxyPorts = lib.mkOption {
      type = lib.types.attrsOf lib.types.port;
      default = {
        sonarr = 8989;
        radarr = 7878;
        prowlarr = 9696;
        qbittorrent = 8888;
      };
    };

    torrentingPort = lib.mkOption {
      type = lib.types.port;
      description = ''
        qbittorrent's listen port, assigned per account by the VPN provider
      '';
    };

    sabnzbdHostWhitelist = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        extra hostnames for sabnzbd's host_whitelist. the hostname caddy proxies it
        under must be listed or requests fail with "Hostname verification failed".
      '';
    };
  };

  config = lib.mkMerge [
    {
      lab = {
        topology = {
          provides = [caps.arr.name];

          # netns arrs are DNAT'd (forward chain), scoped by accessibleFrom instead of the
          # input firewall. sabnzbd is outside the netns
          routes = let
            mw = ["lan_only"] ++ lib.optional (topo.authServerIp != null) "forward_auth";
            arrRoute = openFirewall: sub: port: {
              host = "${sub}.${config.lab.site.domain}";
              inherit port openFirewall;
              middlewares = mw;
            };
            netnsRoute = arrRoute false;
          in
            [
              (netnsRoute "qb" cfg.lanProxyPorts.qbittorrent)
              (netnsRoute "sonarr" cfg.lanProxyPorts.sonarr)
              (netnsRoute "radarr" cfg.lanProxyPorts.radarr)
              (netnsRoute "prowlarr" cfg.lanProxyPorts.prowlarr)
              (arrRoute true "sabnzbd" config.services.sabnzbd.settings.misc.port)
            ]
            ++ lib.optional cfg.slskd.enable (netnsRoute "slskd" config.services.slskd.settings.web.port);
        };

        # bindsTo takes the arrs down with the netns unit: they end up stopped, not
        # failed, so the unit-failed baseline never sees it
        monitoring.alerts = [
          {
            name = "arr vpn down";
            expr = ''systemd_unit_state{name="${vpnNs}.service",state="active"} == bool 0'';
            summary = "vpn netns unit on {{ $labels.instance }} is not active, the arr stack is down with it";
            labels.severity = "critical";
          }
        ];

        # the arrs log more to <name>.txt than stdout. sabnzbd and qbittorrent logs are
        # 0600 and stay journal-only
        logging = {
          extraGroups = [mediaGroup];
          fileSources =
            map (name: {
              job = name;
              path = "${siteData}/${name}/logs/${name}.txt";
            })
            (lib.attrNames arrServices);
        };
      };

      assertions = let
        netnsArrs = lib.filter (n: arrServices.${n}.inNetns) (lib.attrNames arrServices);
        anyArrInNetns = netnsArrs != [];
      in [
        {
          assertion = anyArrInNetns -> lib.all (n: arrServices.${n}.inNetns) (lib.attrNames arrServices);
          message = ''
            arr-stack: all arr services must share the same VPN namespace
            decision. currently in netns: ${lib.concatStringsSep ", " netnsArrs}.
            split residence breaks indexer fan-out (sonarr/radarr reach
            prowlarr on the netns-internal address).
          '';
        }
        {
          assertion = anyArrInNetns -> config.services.qbittorrent.enable;
          message = ''
            arr-stack: arr services are in the VPN namespace but qBittorrent
            is disabled. qbit serves as the in-namespace torrent client and
            must be running.
          '';
        }
      ];
    }

    {
      vpnNamespaces.${vpnNs} = {
        enable = true;
        wireguardConfigFile = config.sops.templates."wg.conf".path;
        inherit (cfg) accessibleFrom;
        allowedEgress = cfg.netnsSnatHosts ++ [vpn.bridgeAddress];
        portMappings = lib.optionals cfg.lanProxy (
          lib.mapAttrsToList (_: port: {
            from = port;
            to = port;
            protocol = "tcp";
          })
          cfg.lanProxyPorts
        );
      };

      # VPN-Confinement drops MTU during wg-quick parsing, set it on the iface ourselves
      systemd.services.${vpnNs}.serviceConfig.ExecStartPost = [
        "${pkgs.iproute2}/bin/ip -n ${vpnNs} link set ${vpnNs}0 mtu ${toString cfg.wgMtu}"
      ];
    }

    {
      sops.secrets =
        lib.genAttrs allSopsRefs (_: {})
        // lib.genAttrs [
          "arr/wg_private_key"
          "arr/wg_peer_public_key"
          "arr/wg_preshared_key"
          "arr/wg_peer_endpoint"
          "arr/wg_address"
        ] (_: {});

      sops.templates =
        {
          "wg.conf" = {
            content = wgConfTemplate;
            mode = "0400";
          };
        }
        // lib.mapAttrs' (name: svc:
          lib.nameValuePair "${name}.env" {
            content = mkEnvFileContent name svc;
            # default root 0400 on purpose: systemd reads EnvironmentFile as root, and a
            # media-group mode would leak the pg password to every media member
          })
        arrServices;
    }

    # a remote db box declares the role itself
    (lib.mkIf dbIsLocal {
      lab.postgres = {
        # the veth bridge isn't a fleet hostIp, so client.enable can't derive it
        extraAllowedCidrs = ["${vpn.bridgeAddress}/24"];
        roles.${arrPgUser} = {
          passwordSecret = arrPgPassSecret;
          owns = arrDbs;
        };
      };
    })

    {
      services = lib.mkMerge (lib.mapAttrsToList (name: svc:
        lib.optionalAttrs svc.hasNixosModule {
          ${name} = {
            enable = true;
            group = mediaGroup;
            dataDir = "${siteData}/${name}";
            environmentFiles = [config.sops.templates."${name}.env".path];
            # mirror the env-injected values so the module defaults don't override them
            settings = {
              auth.method = "Forms";
              auth.required = "DisabledForLocalAddresses";
              log.level = "info";
            };
          };
        })
      arrServices);
    }

    {
      users.groups.${mediaGroup}.gid = config.lab.media.gid;
      users.users = lib.mkMerge [
        (lib.mapAttrs' (name: svc:
          lib.nameValuePair (svc.user or name) {
            isSystemUser = true;
            inherit (svc) uid;
            group = mediaGroup;
            home = "${siteData}/${name}";
          }) (lib.filterAttrs (_: svc: !svc.hasNixosModule) arrServices))

        (lib.mapAttrs' (name: svc:
          lib.nameValuePair (svc.user or name) {inherit (svc) uid;})
        (lib.filterAttrs (_: svc: svc.hasNixosModule && svc ? uid) arrServices))
      ];

      # upstream only sets StateDirectory for the default dataDir, without it the unit
      # fails "Cannot create AppFolder"
      systemd.tmpfiles.rules = lib.mapAttrsToList (name: svc: let
        owner = svc.user or name;
      in "d ${siteData}/${name} 0750 ${owner} ${mediaGroup} -")
      arrServices;
    }

    {
      systemd.services = lib.mkMerge [
        (lib.mapAttrs (name: svc:
          if svc.hasNixosModule
          then arrDeps svc
          else
            # recursiveUpdate, // would drop arrDeps' serviceConfig
            lib.recursiveUpdate (arrDeps svc) {
              description = lib.toSentenceCase name;
              wantedBy = ["multi-user.target"];
              serviceConfig = {
                Type = "simple";
                User = svc.user or name;
                Group = mediaGroup;
                ExecStart = "${pkgs.${name}}/bin/${lib.toSentenceCase name} -nobrowser -data=${siteData}/${name}";
                EnvironmentFile = [config.sops.templates."${name}.env".path];
                Restart = "on-failure";
              };
            })
        arrServices)

        {
          qbittorrent = arrDeps {inNetns = true;};
        }

        (lib.mapAttrs (_: _: arrDbGate) arrServices)
      ];
    }
  ];
}
