# a bind9 resolver: authoritative for an internal split-horizon zone, recursive + DNSSEC for
# everything else, optional RPZ blocklists, optional keepalived VIP. site-agnostic -- the zone
# (name + file), the trusted client ranges, and the RPZ lists are all options, so any site can
# run its own resolver (mesa supplies its zone via the dns host configs / the mesa site layer).
#
# why bind over unbound: unbound is a recursive resolver with local-data bolted on, and a
# redirect zone can't hold per-name overrides (e.g. a wildcard plus one exception). bind is an
# authoritative server, so the split-horizon zone is a first-class `view` + a real zone file.
#
# the NixOS services.bind module models a flat zone list, not views (a view WRAPS its zones), so
# we hand it a full named.conf via configFile. that skips the module's build-time named-checkconf,
# so we run it ourselves below to keep the check.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lab.bind;

  rpzDir = "/var/lib/named/rpz";

  # a minimal valid RPZ zone: SOA + NS, no policy records. named refuses to load a zone whose
  # file is empty or missing, so each RPZ file is seeded with this before the first fetch (the
  # timer in rpz.nix overwrites it with the real list, which carries its own SOA). a bare empty
  # file would fail named-checkconf -z and the zone wouldn't load.
  rpzStub = pkgs.writeText "rpz-empty.zone" ''
    $TTL 30
    @ IN SOA localhost. hostmaster.localhost. 1 3600 900 604800 30
      IN NS  localhost.
  '';

  # one policy zone per configured RPZ list; the fetched/converted file lives in rpzDir.
  rpzZones =
    map (l: {
      name = l.name;
      file = "${rpzDir}/${l.name}";
    })
    cfg.rpzLists;

  # RPZ zone definitions. with views in play, every zone must live INSIDE a view, so these go
  # in the internal view (not at top level -- bind: "all zones must be in views"). and the
  # response-policy referencing them must be in the same view, or bind can't resolve them.
  # no allow-query restriction here: the RPZ engine does an INTERNAL lookup against the policy
  # zone to find matches, and allow-query { none; } refuses that lookup too (the symptom is
  # "query '<name>.<zone>/CNAME/IN' denied" in the log and zero rewrites). the zone is only ever
  # consulted by the engine for clients already in the internal view, so it needs no extra ACL.
  rpzZoneClauses =
    lib.concatMapStrings (z: ''
      zone "${z.name}" {
        type master;
        file "${z.file}";
      };
    '')
    rpzZones;

  # the response-policy clause inside the internal view: apply each RPZ in order. qname-wait-recurse
  # no speeds up the common case (a blocked name never recurses). empty when no lists configured.
  responsePolicy = lib.optionalString (rpzZones != []) ''
    response-policy {
      ${lib.concatMapStrings (z: ''zone "${z.name}";'' + "\n      ") rpzZones}
    } qname-wait-recurse no;
  '';

  # internal clients: get the authoritative view, recursion, and RPZ filtering. everyone else
  # gets refused, so this box can't be used as an open resolver if it's ever exposed.
  internalAcl = ''
    acl internal {
      127.0.0.0/8;
      ::1;
      ${lib.concatMapStrings (r: r + ";\n      ") cfg.trustedRanges}
    };
  '';

  namedConf = pkgs.writeText "named.conf" ''
    # rndc control channel. overriding configFile drops the controls clause the nixpkgs module
    # would normally add, so the rpz refresh's `rndc reload` fails with "connection closed" and
    # the new blocklists never load into the running server. the module's ExecStartPre still
    # generates /etc/bind/rndc.key (key name "rndc-key"), so we just include it + open the channel.
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

      # full recursion from the roots with DNSSEC validation (the default in bind 9.16+, stated
      # explicitly). no forwarders -- forwarding to the router is what created the unbound loop.
      recursion yes;
      dnssec-validation auto;

      # bind picks up the keepalived VIP without a restart: rescan local interfaces every 60s so
      # a freshly-floated VIP gets a listening socket. (the alternative, listen-on { any; }, still
      # needs the rescan to bind a newly-appeared address.)
      interface-interval 60;
    };

    # internal view: the trusted clients. authoritative <zone> + recursion + RPZ blocking. every
    # zone (the site zone, the RPZ policy zones, the root hints) lives here -- with views, zones
    # can't be at top level.
    #
    # allow-recursion + allow-query-cache must be set HERE, scoped to the view: they were at the
    # options level originally, but that conflicted with the external view's `recursion no`, so
    # they moved in. without them bind defaults allow-query-cache to localhost only, and clients
    # get "query (cache) denied" + recursion times out. match-clients already gates this view to
    # `internal`, so allowing the same set for recursion/cache is consistent.
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

    # external view: anything not matched above. refuse -- this resolver is LAN-only, and an
    # exposed open resolver is an abuse vector. recursion no + empty allow-query; no zones.
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
    };
  };

  config = lib.mkIf cfg.enable {
    services.bind = {
      enable = true;
      configFile = namedConf;
      # query upstream over IPv4 only (passes -4 to named). the WAN is v4-only; the LAN has
      # ULAs (fd8d:...) which are non-routable past the LAN, so there is NO path to a public v6
      # nameserver. without -4 bind picks up the ULA, tries v6 root/auth servers, hits "network
      # unreachable", and recursion stalls until the query deadline -> timeouts on uncached names.
      ipv4Only = true;
    };

    # configFile skips the module's named-checkconf; run it ourselves at build so a broken
    # named.conf fails the build instead of the box. no -z: that would load every zone (incl the
    # huge RPZ files, which don't exist at build), we only want the syntax check. two sandbox
    # fixups, neither affects what runs on the box:
    #   - named-checkconf chdirs into the runtime `directory` (/run/named), not writable here, so
    #     repoint it at the sandbox cwd. all our zone paths are absolute, so the value is inert.
    #   - the rndc.key include points at /etc/bind/rndc.key, which only exists at runtime; generate
    #     a throwaway key and repoint the include at it so the syntax check has a real file to read.
    system.checks = lib.mkIf config.services.bind.checkConfig [
      (pkgs.runCommand "named-checkconf" {} ''
        ${lib.getExe' pkgs.bind "rndc-confgen"} -a -c rndc.key >/dev/null 2>&1
        sed -e 's#directory "${config.services.bind.directory}";#directory ".";#' \
            -e 's#include "/etc/bind/rndc.key";#include "rndc.key";#' \
            ${namedConf} > named.conf
        ${lib.getExe' pkgs.bind "named-checkconf"} named.conf && touch $out
      '')
    ];

    # seed each RPZ file with the minimal-valid stub so named starts before the first fetch.
    # C copies the stub only if the target doesn't exist, so a real fetched list is never
    # clobbered on rebuild/reboot.
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
