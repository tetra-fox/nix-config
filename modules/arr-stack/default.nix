{
  config,
  lib,
  pkgs,
  modules,
  siteData,
  siteEnvFile,
  nixosConfigurations,
  ...
}: let
  cfg = config.lab.arrStack;
  arrLib = import ./lib.nix {inherit lib;};

  arrPgUser = "arr";

  # VPN-Confinement caps namespace names at 7 chars (used as unit + iface suffix)
  vpnNs = "wg";
  vpn = config.vpnNamespaces.${vpnNs};

  # where the site's postgres server lives (same derive monitoring uses for grafana).
  # null until some site host sets lab.postgres.server.enable.
  dbServerIp =
    (import ../monitoring/site-topology.nix {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }).dbServerIp;

  # the address the arrs (in the wg netns) use to reach postgres. if THIS host runs the
  # db, postgres is local and the netns reaches it over the veth bridge. otherwise it's
  # the derived db-server IP on the LAN (netnsSnatHosts must include it for the return
  # path). this flips automatically when server.enable moves off this host in Phase 3.
  defaultPostgresHost =
    if config.lab.postgres.server.enable
    then vpn.bridgeAddress
    else dbServerIp;

  arrServices = {
    sonarr = {
      port = cfg.lanProxyPorts.sonarr;
      inNetns = true;
      apiKey = {_sops = "apps/sonarr_api_key";};
      hasNixosModule = true;
      uid = 274; # pinned so the uid is identical across boxes (NFS share)
    };
    radarr = {
      port = cfg.lanProxyPorts.radarr;
      inNetns = true;
      apiKey = {_sops = "apps/radarr_api_key";};
      hasNixosModule = true;
      uid = 275; # pinned so the uid is identical across boxes (NFS share)
    };
    prowlarr = {
      port = cfg.lanProxyPorts.prowlarr;
      inNetns = true;
      # services.prowlarr has no environmentFiles option; we define the unit ourselves
      apiKey = null;
      hasNixosModule = false;
      user = "prowlarr";
      uid = 276; # next after radarr (275)
    };
  };

  baseSettings = {
    auth = {
      method = "Forms";
      required = "DisabledForLocalAddresses";
    };
    log.level = "info";
    postgres = {
      # netns clients reach pg via the bridge's host-side address by default; override
      # with cfg.postgresHost (+ netnsSnatHosts) when postgres moves to another box
      host = cfg.postgresHost;
      port = 5432;
      user = arrPgUser;
      password = {_sops = "arr/pg_pass";};
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

  # the password-ownership oneshot only exists where postgres runs. when the db is local
  # the arrs gate on it (avoids a bad-creds crash-loop during the boot race); when it's
  # remote that unit lives on the db box, so we don't reference it -- the arrs just retry
  # the connection until db-01 answers.
  dbIsLocal = config.lab.postgres.server.enable;
  pgPasswordUnit = lib.optional dbIsLocal config.lab.postgres.passwordUnits.${arrPgUser};

  # vpnConfinement already adds bindsTo+after on the wg unit; the extra
  # `requires` here is belt-and-suspenders fail-closed
  arrDeps = svc: {
    after = pgPasswordUnit;
    requires =
      pgPasswordUnit
      ++ lib.optional svc.inNetns "${vpnNs}.service";
    vpnConfinement = lib.optionalAttrs svc.inNetns {
      enable = true;
      vpnNamespace = vpnNs;
    };
    # the arrs create show/season dirs in the shared media library; the servarr
    # nixos modules hardcode UMask 0022, which makes those dirs group-unwritable
    # so a later import by another media-group service (or the same one) hits
    # UnauthorizedAccessException. mkForce 0002 keeps dirs 0775 and files 0664 so
    # the whole media group can collaborate on the library
    serviceConfig.UMask = lib.mkForce "0002";
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
    ./qbittorrent.nix
    ./sabnzbd.nix
    ./recyclarr.nix
    ./downloadclients.nix
    ./jellyfin-notify.nix
    ./cleanup-profiles.nix
    modules.postgres.system
  ];

  options.lab.arrStack = {
    lanProxy =
      lib.mkEnableOption "DNAT host ports into the vpn netns for LAN access"
      // {default = true;};

    mediaGroup = lib.mkOption {
      type = lib.types.str;
      default = "media";
    };

    torrentsPath = lib.mkOption {type = lib.types.str;};
    nzbPath = lib.mkOption {type = lib.types.str;};

    accessibleFrom = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["192.168.0.0/16" "10.0.0.0/8"];
      description = "subnets allowed to reach the namespace via portMappings; covers return-route for any LAN client";
    };

    postgresHost = lib.mkOption {
      type = lib.types.str;
      default = defaultPostgresHost;
      description = ''
        host the arrs connect to for postgres. auto-derived: the veth bridge address
        when this host runs the db (postgres is local), else the site's derived
        db-server IP. when the db is remote, add that IP to netnsSnatHosts so the netns
        gets its return path. override only for a non-fleet target.
      '';
    };

    netnsSnatHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        LAN IPs whose netns-initiated traffic must be SNAT'd to this host's LAN address
        so they can reply. the accessibleFrom routes already take LAN destinations off
        the tunnel, but replies would target the private namespaceAddress (unroutable on
        the LAN) without this masquerade. populate when a service the arrs talk to moves
        to another box (postgres, jellyfin). empty = no masquerade, behaves as before.
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

    sabnzbdHostWhitelist = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        extra hostnames to add to sabnzbd's host_whitelist. sabnzbd rejects requests
        whose Host header isn't whitelisted (dns-rebinding protection), so the public
        hostname caddy proxies it under (e.g. sabnzbd.<site>.tetra.cool) must be listed
        here or you get "Hostname verification failed".
      '';
    };
  };

  config = lib.mkMerge [
    {
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
        accessibleFrom = cfg.accessibleFrom;
        portMappings = lib.optionals cfg.lanProxy (
          lib.mapAttrsToList (_: port: {
            from = port;
            to = port;
            protocol = "tcp";
          })
          cfg.lanProxyPorts
        );
      };

      # VPN-Confinement drops MTU during wg-quick parsing; set it on the iface ourselves.
      # also masquerade netns-initiated traffic to each netnsSnatHosts dest so the reply
      # comes back: accessibleFrom already routes these LAN dests off the tunnel, but
      # without SNAT the dest sees the private namespaceAddress and can't reply. scoped to
      # -d <ip>/32 so it never touches the inbound portMappings DNAT flows or tunnel egress.
      # no -o <iface>: the dest decides the output interface (ens18 for the server VLAN,
      # ens19 for the isolated internal VLAN), and the -d /32 scope is already tight.
      systemd.services.${vpnNs}.serviceConfig = {
        ExecStartPost =
          [
            "${pkgs.iproute2}/bin/ip -n ${vpnNs} link set ${vpnNs}0 mtu ${toString cfg.wgMtu}"
          ]
          ++ map (
            ip: "${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s ${vpn.namespaceAddress}/24 -d ${ip}/32 -j MASQUERADE"
          )
          cfg.netnsSnatHosts;

        # tear the masquerade rules down when the netns stops, so a restart doesn't stack
        # duplicate rules (ExecStartPost re-appends on every start). leading - ignores a
        # missing rule.
        ExecStopPost =
          map (
            ip: "-${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s ${vpn.namespaceAddress}/24 -d ${ip}/32 -j MASQUERADE"
          )
          cfg.netnsSnatHosts;
      };
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
            group = cfg.mediaGroup;
            mode = "0440";
          })
        arrServices;
    }

    # only contribute the arr role/cidr when postgres runs on THIS host. when the db is
    # remote, the db box (mesa-db-01) declares the arr role + its own allowedCidrs, so
    # svc-01 must not -- it's a pure client here.
    (lib.mkIf dbIsLocal {
      lab.postgres = {
        # the netns reaches a LOCAL pg over the veth bridge (192.168.15.x), not a fleet
        # hostIp, so this must be an explicit extra (not derivable from client.enable).
        # /24 spans both ends of the bridge.
        extraAllowedCidrs = ["${vpn.bridgeAddress}/24"];
        roles.${arrPgUser} = {
          passwordSecret = "arr/pg_pass";
          owns = arrDbs;
        };
      };
    })

    {
      services = lib.mkMerge (lib.mapAttrsToList (name: svc:
        lib.optionalAttrs svc.hasNixosModule {
          ${name} = {
            enable = true;
            group = cfg.mediaGroup;
            dataDir = "${siteData}/${name}";
            environmentFiles = siteEnvFile "${name}.env";
            # mirror the env-injected values so the module's defaults don't override them
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
      users.groups.${cfg.mediaGroup} = {};
      users.users = lib.mkMerge [
        # services we define ourselves (no upstream nixos module): create the user here.
        (lib.mapAttrs' (name: svc:
          lib.nameValuePair (svc.user or name) {
            isSystemUser = true;
            uid = svc.uid;
            group = cfg.mediaGroup;
            home = "${siteData}/${name}";
          }) (lib.filterAttrs (_: svc: !svc.hasNixosModule) arrServices))

        # services with an upstream module already create the user; pin only its uid so
        # it stays identical across boxes (the NFS share squashes on uid, not name).
        (lib.mapAttrs' (name: svc:
          lib.nameValuePair (svc.user or name) {uid = svc.uid;})
        (lib.filterAttrs (_: svc: svc.hasNixosModule && svc ? uid) arrServices))
      ];

      # every service gets its data dir created here, including the ones with a nixos
      # module: upstream sonarr/radarr only set StateDirectory (which creates the dir)
      # when dataDir is left at the default, and we override it to siteData, so the dir
      # is ours to create or the unit fails on "Cannot create AppFolder".
      systemd.tmpfiles.rules = lib.mapAttrsToList (name: svc: let
        owner = svc.user or name;
      in "d ${siteData}/${name} 0750 ${owner} ${cfg.mediaGroup} -")
      arrServices;
    }

    {
      systemd.services = lib.mkMerge [
        (lib.mapAttrs (name: svc:
          if svc.hasNixosModule
          then arrDeps svc
          else
            arrDeps svc
            // {
              description = lib.toSentenceCase name;
              wantedBy = ["multi-user.target"];
              serviceConfig = {
                Type = "simple";
                User = svc.user or name;
                Group = cfg.mediaGroup;
                ExecStart = "${pkgs.${name}}/bin/${lib.toSentenceCase name} -nobrowser -data=${siteData}/${name}";
                EnvironmentFile = siteEnvFile "${name}.env";
                Restart = "on-failure";
              };
            })
        arrServices)

        {
          qbittorrent = arrDeps {inNetns = true;};
        }
      ];
    }
  ];
}
