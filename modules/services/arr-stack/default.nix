{
  config,
  lib,
  pkgs,
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

  # the single db server's IP, or the HA cluster's VIP. null until a host enables either
  inherit (topo) dbEndpointIp;

  # local db is reached over the veth bridge, remote db at its LAN endpoint
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
      # services.prowlarr has no environmentFiles option, so we define the unit ourselves
      apiKey = null;
      hasNixosModule = false;
      user = "prowlarr";
      uid = 276;
    };
  };

  baseSettings = {
    auth = {
      method = "Forms";
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

  # gate the arrs on the password oneshot when the db is local, avoiding a bad-creds
  # crash-loop during the boot race. remote db has no such unit, the arrs just retry
  dbIsLocal = config.lab.postgres.server.enable;
  pgPasswordUnit = lib.optional dbIsLocal config.lab.postgres.passwordUnits.${arrPgUser};

  # vpnConfinement already binds the arrs to the wg unit; the extra `requires` is a
  # redundant fail-closed guard, keep it
  arrDeps = svc: {
    after = pgPasswordUnit;
    requires =
      pgPasswordUnit
      ++ lib.optional svc.inNetns "${vpnNs}.service";
    vpnConfinement = lib.optionalAttrs svc.inNetns {
      enable = true;
      vpnNamespace = vpnNs;
    };
    # servarr modules hardcode UMask 0022, making library dirs group-unwritable so a
    # later import by another media-group service hits UnauthorizedAccessException.
    # 0002 keeps dirs 0775 / files 0664 for the whole media group
    serviceConfig.UMask = lib.mkForce "0002";
  };

  # the arrs don't retry a failed initial db connection: on a db that isn't up yet they log
  # "Non-recoverable failure, waiting for user intervention" and park with the process still
  # alive, so Restart=on-failure never fires and a boot race against the db -- or a leader
  # failover -- leaves them down until a manual restart. gate startup on the primary answering.
  # pg_isready does the real startup handshake, so it reports not-ready even when haproxy
  # accepts the tcp connection with no healthy backend; postgresHost is the VIP, which only
  # routes to the read-write primary, so a ready answer means promoted and writable.
  # TimeoutStartSec bounds the wait: on timeout the unit fails cleanly and Restart retries,
  # instead of the app parking with no exit for systemd to act on.
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
    ./qbittorrent.nix
    ./sabnzbd.nix
    ./recyclarr.nix
    ./downloadclients.nix
    ./jellyfin-notify.nix
    ./cleanup-profiles.nix
    # the client options contract, not the server module: the arrs are a pg client. the host
    # imports postgres.system itself when it also runs the server (co-located single-box site)
    modules.services.postgres.options
    # options-only, registers the vpn-down alert without pulling in the monitoring stack
    modules.services.monitoring.registry
  ];

  options.lab.arrStack = {
    lanProxy =
      lib.mkEnableOption "DNAT host ports into the vpn netns for LAN access"
      // {default = true;};

    # published so the db host reads the whole role spec (name, secret, dbs) off this host
    # via topo.arrDbRole instead of restating any of it. readOnly with a static default,
    # so the cross-host read can't cycle.
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
      default = config.lab.net.privateRanges;
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
      # a remote db needs SNAT so its replies route back; a local db has nothing to SNAT
      default = lib.optional (!dbIsLocal && dbEndpointIp != null) dbEndpointIp;
      description = ''
        LAN IPs whose netns-initiated traffic must be SNAT'd to this host's LAN address
        so they can reply. the accessibleFrom routes already take LAN destinations off
        the tunnel, but replies would target the private namespaceAddress (unroutable on
        the LAN) without this masquerade. defaults to the remote db's IP; populate with
        extra dests when another off-box service (jellyfin) is added.
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
        qbittorrent's incoming (listen) port. the VPN provider assigns this per account
        when port forwarding is set up, so it's a deployment fact with no sane default.
      '';
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
      lab.topology.provides = [caps.arr.name];

      # bindsTo takes the arrs down with the netns unit: they end up stopped, not
      # failed, so the unit-failed baseline never sees it
      lab.monitoring.alerts = [
        {
          name = "arr vpn down";
          expr = ''systemd_unit_state{name="${vpnNs}.service",state="active"} == bool 0'';
          summary = "vpn netns unit on {{ $labels.instance }} is not active, the arr stack is down with it";
          labels.severity = "critical";
        }
      ];

      # the arrs log more to their <name>.txt than to stdout, so ship those to the site
      # loki too; the media group grants alloy read on the 0644/0664 files. sabnzbd and
      # qbittorrent logs are 0600 and stay journal-only.
      lab.logging = {
        extraGroups = [mediaGroup];
        fileSources =
          map (name: {
            job = name;
            path = "${siteData}/${name}/logs/${name}.txt";
          })
          (lib.attrNames arrServices);
      };

      assertions = let
        netnsArrs = lib.filter (n: arrServices.${n}.inNetns) (lib.attrNames arrServices);
        anyArrInNetns = netnsArrs != [];
      in [
        {
          # the arrs run in a wg netns; the host must wire vpn-confinement (fleet-wide via
          # perClass.nixos today) or the vpnNamespaces option below doesn't exist
          assertion = config ? vpnNamespaces;
          message = "arr-stack needs the vpn-confinement module (vpnNamespaces option) wired on this host.";
        }
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
        # the non-tunnel flows the arrs initiate: the remote db (netnsSnatHosts) and
        # host-side sabnzbd at the bridge address. allowedEgress is our upstream PR
        # (Maroka-chan/VPN-Confinement#48), consumed from the fork branch until it merges
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

      # masquerade netns-initiated traffic to each dest so replies come back: without
      # SNAT the dest sees the private namespaceAddress and can't reply. a declarative
      # nftables table, not an ExecStartPost rule, so an `nft` reload doesn't wipe it.
      # scoped per-dest so it never touches the inbound portMappings DNAT return flows
      networking.nftables.tables.arr-netns-snat = lib.mkIf (cfg.netnsSnatHosts != []) {
        family = "ip";
        content = ''
          chain postrouting {
            type nat hook postrouting priority srcnat; policy accept;
            ${lib.concatMapStringsSep "\n    " (
              ip: "ip saddr ${vpn.namespaceAddress}/24 ip daddr ${ip} masquerade"
            )
            cfg.netnsSnatHosts}
          }
        '';
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
            group = mediaGroup;
            mode = "0440";
          })
        arrServices;
    }

    # only contribute the arr role/cidr when the db is local; the remote db box declares
    # them itself and this host is a pure client
    (lib.mkIf dbIsLocal {
      lab.postgres = {
        # netns reaches local pg over the veth bridge, not a fleet hostIp, so it can't be
        # derived from client.enable. /24 spans both ends of the bridge
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
      users.groups.${mediaGroup}.gid = config.lab.media.gid;
      users.users = lib.mkMerge [
        (lib.mapAttrs' (name: svc:
          lib.nameValuePair (svc.user or name) {
            isSystemUser = true;
            inherit (svc) uid;
            group = mediaGroup;
            home = "${siteData}/${name}";
          }) (lib.filterAttrs (_: svc: !svc.hasNixosModule) arrServices))

        # upstream module already creates the user, pin only its uid
        (lib.mapAttrs' (name: svc:
          lib.nameValuePair (svc.user or name) {inherit (svc) uid;})
        (lib.filterAttrs (_: svc: svc.hasNixosModule && svc ? uid) arrServices))
      ];

      # upstream sets StateDirectory (which creates the dir) only when dataDir is the
      # default; we override it, so we create the dir or the unit fails "Cannot create
      # AppFolder"
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
            arrDeps svc
            // {
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

        # block each arr's startup until its postgres primary answers (see waitForDb).
        # qbittorrent is excluded here: it has no database.
        (lib.mapAttrs (_: _: arrDbGate) arrServices)
      ];
    }
  ];
}
