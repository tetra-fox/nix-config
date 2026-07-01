# bind over unbound: unbound's redirect zone can't hold per-name overrides (a wildcard plus one
# exception), bind's split-horizon `view` can.
#
# the NixOS services.bind module models a flat zone list, not views, so we hand it a full
# named.conf via configFile. that skips the module's named-checkconf, so we run it ourselves below.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lab.bind;

  rpzDir = "/var/lib/named/rpz";

  # named refuses to load a zone whose file is empty or missing, so each RPZ file is seeded with
  # this SOA+NS stub before the first fetch.
  rpzStub = pkgs.writeText "rpz-empty.zone" ''
    $TTL 30
    @ IN SOA localhost. hostmaster.localhost. 1 3600 900 604800 30
      IN NS  localhost.
  '';

  rpzZones =
    map (l: {
      inherit (l) name;
      file = "${rpzDir}/${l.name}";
    })
    cfg.rpzLists;

  # with views in play every zone must live inside a view, so these (and the response-policy
  # referencing them) go in the internal view, not at top level.
  # no allow-query { none; }: the RPZ engine does an internal lookup against the policy zone and
  # that ACL refuses it too (symptom: "query '<name>.<zone>/CNAME/IN' denied" + zero rewrites).
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
      ${lib.concatMapStrings (r: r + ";\n      ") cfg.trustedRanges}
    };
  '';

  namedConf = pkgs.writeText "named.conf" ''
    # configFile drops the controls clause the module adds, so the rpz refresh's `rndc reload`
    # fails with "connection closed". the module's ExecStartPre still generates rndc.key.
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

      # no forwarders: the router points its upstream DNS back here, so forwarding would loop.
      recursion yes;
      dnssec-validation auto;

      # rescan interfaces so a freshly-floated keepalived VIP gets a listening socket without a restart.
      interface-interval 60;
    };

    # allow-recursion + allow-query-cache go here, not options: at options level they conflict with
    # the external view's `recursion no`, and their default (localhost) makes internal clients get
    # "query (cache) denied" + recursion timeouts.
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
      default = ["192.168.0.0/16" "10.0.0.0/8"];
      description = "client ranges that get the internal view (recursion + the authoritative zone + RPZ)";
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
          GUA -- a residential ISP prefix rotates, and a GUA VIP would break on every rotation.
          each resolver host also needs a static ULA on ens18 (lab.bind.ha.hostV6) to source the
          v6 VRRP heartbeat + hold the VIP. null = v4-only (mesa).
        '';
      };
      hostV6 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "this resolver's own static ULA on ens18 (the v6 heartbeat source); paired with vip6.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    lab.topology.provides = ["dns"];

    services.bind = {
      enable = true;
      configFile = namedConf;
      # -4: the WAN is v4-only, so without it bind tries v6 root/auth servers over the non-routable
      # LAN ULA, hits "network unreachable", and recursion stalls until the deadline.
      ipv4Only = true;
    };

    # run named-checkconf at build so a broken named.conf fails the build, not the box. no -z: it
    # would load every zone incl the RPZ files, which don't exist at build; we only want the syntax
    # check. two sandbox fixups, inert on the box: repoint `directory` at the sandbox cwd (the
    # runtime /run/named isn't writable here, our zone paths are absolute anyway), and swap the
    # rndc.key include for a throwaway key (the real one only exists at runtime).
    system.checks = lib.mkIf config.services.bind.checkConfig [
      (pkgs.runCommand "named-checkconf" {} ''
        ${lib.getExe' pkgs.bind "rndc-confgen"} -a -c rndc.key >/dev/null 2>&1
        sed -e 's#directory "${config.services.bind.directory}";#directory ".";#' \
            -e 's#include "/etc/bind/rndc.key";#include "rndc.key";#' \
            ${namedConf} > named.conf
        ${lib.getExe' pkgs.bind "named-checkconf"} named.conf && touch $out
      '')
    ];

    # C seeds the stub only if the target is absent, so a real fetched list is never clobbered.
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
