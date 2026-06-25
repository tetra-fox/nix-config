{
  config,
  lib,
  pkgs,
  modules,
  siteData,
  siteEnvFile,
  ...
}: let
  cfg = config.lab.arrStack;
  arrLib = import ./lib.nix {inherit lib;};

  arrPgUser = "arr";

  # VPN-Confinement caps namespace names at 7 chars (used as unit + iface suffix)
  vpnNs = "wg";
  vpn = config.vpnNamespaces.${vpnNs};

  arrServices = {
    sonarr = {
      port = cfg.lanProxyPorts.sonarr;
      inNetns = true;
      apiKey = {_sops = "apps/sonarr_api_key";};
      hasNixosModule = true;
    };
    radarr = {
      port = cfg.lanProxyPorts.radarr;
      inNetns = true;
      apiKey = {_sops = "apps/radarr_api_key";};
      hasNixosModule = true;
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
      # netns clients reach pg via the bridge's host-side address
      host = vpn.bridgeAddress;
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

  # vpnConfinement already adds bindsTo+after on the wg unit; the extra
  # `requires` here is belt-and-suspenders fail-closed
  arrDeps = svc: {
    after = [config.lab.postgres.passwordUnits.${arrPgUser}];
    requires =
      [config.lab.postgres.passwordUnits.${arrPgUser}]
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

      # VPN-Confinement drops MTU during wg-quick parsing; set it on the iface ourselves
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
            group = cfg.mediaGroup;
            mode = "0440";
          })
        arrServices;
    }

    {
      lab.postgres = {
        # /24 spans both ends of the veth bridge so netns clients can reach pg
        allowedCidrs = ["${vpn.bridgeAddress}/24"];
        roles.${arrPgUser} = {
          passwordSecret = "arr/pg_pass";
          owns = arrDbs;
        };
      };
    }

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
      users.users = lib.mapAttrs' (name: svc:
        lib.nameValuePair (svc.user or name) {
          isSystemUser = true;
          uid = svc.uid;
          group = cfg.mediaGroup;
          home = "${siteData}/${name}";
        }) (lib.filterAttrs (_: svc: !svc.hasNixosModule) arrServices);

      # every service gets its data dir created here, including the ones with a nixos
      # module: upstream sonarr/radarr only set StateDirectory (which creates the dir)
      # when dataDir is left at the default, and we override it to siteData, so the dir
      # is ours to create or the unit fails on "Cannot create AppFolder".
      systemd.tmpfiles.rules = lib.mapAttrsToList (name: svc: let
        owner = svc.user or name;
      in "d ${siteData}/${name} 0750 ${owner} ${cfg.mediaGroup} -") arrServices;
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
