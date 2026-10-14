# a fictional non-mesa fleet. if this ever needs an engine.nix change to pass, the engine
# stopped being generic. run with `just fleet-test`
{lib}: let
  engine = import ./engine.nix {inherit lib;};

  cfgs = {
    acme-cache-01 = {
      config = {
        networking.hostName = "acme-cache-01";
        lab = {
          site.hostIp = "10.0.0.1";
          site.internalIp = "10.1.0.1";
          topology.provides = ["cache-node" "metrics"];
          topology.routes = [
            {
              host = "cache1.acme.example";
              port = 9000;
            }
          ];
          # cachevip matches its peer (HA fall-through test), badvip diverges (throw test)
          cachevip.vip = "10.1.0.100";
          badvip.vip = "10.1.0.1";
        };
      };
    };
    acme-cache-02 = {
      config = {
        networking.hostName = "acme-cache-02";
        lab = {
          site.hostIp = "10.0.0.2";
          topology.provides = ["cache-node"];
          cachevip.vip = "10.1.0.100";
          badvip.vip = "10.1.0.2";
        };
      };
    };
    acme-web-01 = {
      config = {
        networking.hostName = "acme-web-01";
        lab = {
          site.hostIp = "10.0.0.3";
          topology.provides = ["web"];
          # two routes: a multi-route provider for the publicUrlProviding throw test
          topology.routes = [
            {
              host = "web.acme.example";
              port = 80;
            }
            {
              host = "admin.acme.example";
              port = 8080;
            }
          ];
        };
      };
    };
    beta-cache-01 = {
      config = {
        networking.hostName = "beta-cache-01";
        lab = {
          site.hostIp = "10.9.9.1";
          topology.provides = ["cache-node"];
          # a route in another site, to prove routesInSite excludes it
          topology.routes = [
            {
              host = "cache.beta.example";
              port = 9000;
            }
          ];
        };
      };
    };
  };

  f = engine {
    nixosConfigurations = cfgs;
    hostName = "acme-web-01";
  };

  checks = [
    {
      name = "site scoping excludes other sites";
      ok = f.hostsProviding "cache-node" == ["acme-cache-01" "acme-cache-02"];
    }
    # cache-01 has both ips, cache-02 only hostIp
    {
      name = "ipsProviding prefers internalIp, falls back to hostIp";
      ok = f.ipsProviding "cache-node" == ["10.1.0.1" "10.0.0.2"];
    }
    {
      name = "single-provider capability resolves";
      ok = f.ipProviding "metrics" == "10.1.0.1";
    }
    {
      name = "absent capability is null/empty, not an error";
      ok = f.ipProviding "nonexistent" == null && f.ipsProviding "nonexistent" == [];
    }
    {
      name = "optionalHaEndpointFor returns the single server while one exists";
      ok =
        f.optionalHaEndpointFor {
          singleCap = "metrics";
          haCap = "metrics-ha";
          vipPath = ["lab" "whatever" "vip"];
        }
        == "10.1.0.1";
    }
    {
      name = "optionalHaEndpointFor falls through to the VIP when no single server exists";
      ok =
        f.optionalHaEndpointFor {
          singleCap = "absent-single";
          haCap = "cache-node";
          vipPath = ["lab" "cachevip" "vip"];
        }
        == "10.1.0.100";
    }
    {
      name = "routesInSite resolves upstreams and scopes to site";
      ok = let
        # sort by host so this tests route membership, not the incidental attrNames fold order
        got = lib.sort (a: b: a.host < b.host) (map (r: {inherit (r) host upstream;}) f.routesInSite);
      in
        got
        == [
          {
            host = "admin.acme.example";
            upstream = "10.0.0.3:8080";
          }
          {
            host = "cache1.acme.example";
            upstream = "10.1.0.1:9000";
          }
          {
            host = "web.acme.example";
            upstream = "10.0.0.3:80";
          }
        ];
    }
    {
      name = "publicUrlProviding returns the single provider's route url";
      ok = f.publicUrlProviding "metrics" == "https://cache1.acme.example";
    }
    {
      name = "publicUrlProviding is null for an absent capability";
      ok = f.publicUrlProviding "nonexistent" == null;
    }
    {
      name = "publicUrlProviding throws on multiple providers";
      ok = !(builtins.tryEval (f.publicUrlProviding "cache-node")).success;
    }
    {
      name = "publicUrlProviding throws when the provider has multiple routes";
      ok = !(builtins.tryEval (f.publicUrlProviding "web")).success;
    }
    {
      name = "ipProviding throws when two hosts claim a single-provider cap";
      ok = !(builtins.tryEval (f.ipProviding "cache-node")).success;
    }
    {
      name = "haEndpointFor points at the sole provider before the pair exists";
      ok =
        f.haEndpointFor {
          cap = "metrics";
          vipPath = ["lab" "cachevip" "vip"];
        }
        == "10.1.0.1";
    }
    {
      name = "haEndpointFor resolves to the VIP when two hosts provide the cap";
      ok =
        f.haEndpointFor {
          cap = "cache-node";
          vipPath = ["lab" "cachevip" "vip"];
        }
        == "10.1.0.100";
    }
    {
      name = "haEndpointFor throws on divergent VIPs";
      ok = let
        r = builtins.tryEval (f.haEndpointFor {
          cap = "cache-node";
          vipPath = ["lab" "badvip" "vip"];
        });
      in
        !r.success;
    }
    # the whole-name rows are bogus tags that fail at the perTag facts-file import
    {
      name = "sitePrefix parses the site off a hostname";
      ok =
        map f.sitePrefix [
          "mesa-db-01"
          "mesa-db-1"
          "hara"
          "mesa-db-01-old"
          "mesa-db-alt-01"
          "mesa-DB-01"
        ]
        == [
          "mesa"
          "mesa"
          "hara"
          "mesa-db-01-old"
          "mesa"
          "mesa-DB-01"
        ];
    }
  ];

  failures = lib.filter (c: !c.ok) checks;
in
  if failures == []
  then "ok"
  else throw "fleet-test failed: ${lib.concatMapStringsSep ", " (c: c.name) failures}"
