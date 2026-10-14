# services.bind has no views, so it gets a whole named.conf via configFile
{
  config,
  lib,
  pkgs,
  caps,
  ...
}: let
  cfg = config.lab.bind;

  inherit (import ./_rpz-common.nix) rpzDir rpzStubText;
  rpzStub = pkgs.writeText "rpz-empty.zone" rpzStubText;

  rpzZones =
    map (l: {
      inherit (l) name;
      file = "${rpzDir}/${l.name}";
    })
    cfg.rpzLists;

  # no allow-query { none; }: it also refuses the rpz engine's own lookups into the zone
  rpzZoneClauses =
    lib.concatMapStrings (z: ''
      zone "${z.name}" {
        type master;
        file "${z.file}";
      };
    '')
    rpzZones;

  responsePolicy = lib.optionalString (rpzZones != []) ''
    response-policy {
      ${lib.concatMapStrings (z: ''zone "${z.name}";'' + "\n      ") rpzZones}
    } qname-wait-recurse no;
  '';

  internalAcl = ''
    acl internal {
      127.0.0.0/8;
      ::1;
      ${lib.concatMapStrings (r: r + ";\n      ") (cfg.trustedRanges ++ cfg.extraTrustedRanges)}
    };
  '';

  namedConf = pkgs.writeText "named.conf" ''
    # configFile drops the module's controls clause, which `rndc reload` needs.
    # the module still generates rndc.key
    include "/etc/bind/rndc.key";
    controls {
      inet 127.0.0.1 allow { localhost; } keys { "rndc-key"; };
    };

    ${internalAcl}

    options {
      directory "${config.services.bind.directory}";
      pid-file "/run/named/named.pid";

      listen-on { any; };
      listen-on-v6 { any; };

      # no forwarders: the router's upstream DNS is this host, forwarding would loop
      recursion yes;
      dnssec-validation auto;

      # default is any, letting every RFC1918 client AXFR the fleet inventory.
      # both hosts are masters of the same generated zone, nothing transfers
      allow-transfer { none; };

      # picks up a newly floated VIP without a restart
      interface-interval 60;
    };

    # allow-recursion and allow-query-cache belong here: in options they conflict with the
    # external view's `recursion no`, and their localhost default denies internal clients
    view "internal" {
      match-clients { internal; };
      recursion yes;
      allow-recursion { internal; };
      allow-query-cache { internal; };
      ${responsePolicy}

      ${rpzZoneClauses}

      zone "${cfg.zone.name}" {
        type master;
        file "${cfg.zone.file}";
      };

      zone "." { type hint; file "${pkgs.dns-root-data}/root.hints"; };
    };

    view "external" {
      match-clients { any; };
      recursion no;
      allow-query { none; };
    };
  '';
in {
  imports = [
    ./rpz.nix
    ./keepalived.nix
  ];

  options.lab.bind = {
    enable = lib.mkEnableOption "a bind9 split-horizon resolver on this host";

    zone = {
      name = lib.mkOption {
        type = lib.types.str;
        example = "mesa.tetra.cool";
        description = "the authoritative split-horizon zone name served to internal clients";
      };
      file = lib.mkOption {
        type = lib.types.path;
        description = "the zone file for zone.name (a real zone file, derives substituted by the caller)";
      };
    };

    trustedRanges = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = config.lab.net.privateRanges;
      description = "client ranges that get the internal view (recursion + the authoritative zone + RPZ)";
    };

    extraTrustedRanges = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "ranges appended to trustedRanges, so a site can add (e.g. v6) ranges without restating the defaults";
    };

    rpzLists = lib.mkOption {
      default = [];
      description = "RPZ blocklists to fetch + apply (empty = no blocking). rpz.nix does the fetch.";
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "the policy zone name + on-disk filename (e.g. \"oisd.rpz\")";
          };
          url = lib.mkOption {
            type = lib.types.str;
            description = "where to fetch the list";
          };
          format = lib.mkOption {
            type = lib.types.enum ["rpz" "hosts"];
            description = "rpz = already an RPZ zone (taken verbatim); hosts = 0.0.0.0 hosts file (converted)";
          };
        };
      });
    };

    dualStack = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        the site has a real dual-stack (v6) WAN. default false = mesa (v4-only WAN): bind runs
        with -4 so it doesn't stall recursion trying v6 upstreams over a non-routable LAN. set
        true on a dual-stack site (fairlane) so bind will bind v6 sockets, including a v6 VIP.
      '';
    };

    ha = {
      enable = lib.mkEnableOption "run keepalived and float the resolver VIP on this host";
      vip = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          the floating virtual IP keepalived parks on a live resolver, on the server VLAN.
          the router's upstream DNS points here; both resolver hosts declare the same value.
        '';
      };
      vip6 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          optional floating IPv6 VIP for dual-stack sites (fairlane). use a ULA (fd00:...) not a
          GUA, a residential ISP prefix rotates, and a GUA VIP would break on every rotation.
          each resolver host also needs a static ULA on ens18 (lab.bind.ha.hostV6) to source the
          v6 VRRP heartbeat + hold the VIP. null = v4-only (mesa).
        '';
      };
      hostV6 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "this resolver's own static ULA on the server-VLAN NIC (the v6 heartbeat source); paired with vip6.";
      };

      virtualRouterId = lib.mkOption {
        type = lib.types.int;
        default = 53;
        description = "VRRP router id for the resolver VIP, unique per L2 segment (see lab.vrrp.virtualRouterId).";
      };

      virtualRouterId6 = lib.mkOption {
        type = lib.types.int;
        default = 63;
        description = "vrid for the v6 VIP instance (only used when vip6 is set); distinct from the v4 one.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    lab.topology.provides = [caps.dns.name];

    services.bind = {
      enable = true;
      configFile = namedConf;
      # on a v4-only WAN bind tries v6 servers over the LAN ULA and stalls recursion.
      # -4 on a dual-stack site refuses every v6 socket, the v6 VIP included
      ipv4Only = !cfg.dualStack;
    };

    # configFile skips the module's own check. no -z: the rpz files don't exist at build.
    # directory and rndc.key are swapped for sandbox-local stand-ins
    system.checks = lib.mkIf config.services.bind.checkConfig [
      (pkgs.runCommand "named-checkconf" {} ''
        ${lib.getExe' pkgs.bind "rndc-confgen"} -a -c rndc.key >/dev/null 2>&1
        sed -e 's#directory "${config.services.bind.directory}";#directory ".";#' \
            -e 's#include "/etc/bind/rndc.key";#include "rndc.key";#' \
            ${namedConf} > named.conf
        ${lib.getExe' pkgs.bind "named-checkconf"} named.conf && touch $out
      '')
    ];

    # C only copies when absent, never clobbering a fetched list
    systemd.tmpfiles.rules =
      ["d ${rpzDir} 0755 named named -"]
      ++ map (z: "C ${z.file} 0644 named named - ${rpzStub}") rpzZones;

    networking.firewall = {
      allowedTCPPorts = [53];
      allowedUDPPorts = [53];
    };

    assertions = [
      {
        assertion = !cfg.ha.enable || cfg.ha.vip != null;
        message = "lab.bind.ha.enable requires lab.bind.ha.vip (the floating resolver endpoint).";
      }
    ];
  };
}
