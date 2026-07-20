# generalization test for engine.nix: a fictional, non-mesa fleet exercising the engine with a
# capability it's never heard of. this is the tell for "real library vs config in a trenchcoat":
# a new capability TYPE (not just a new host) must need zero edits to engine.nix. if this file
# ever needs an engine change to pass, the engine isn't generic -- it just looked generic
# because the mesa capability set happened to be complete.
#
# run: nix eval --impure --expr 'import ./lib/fleet-test.nix { lib = (builtins.getFlake (toString ./.)).inputs.nixpkgs.lib; }'
# returns the string "ok" on success, or throws with the failing assertion.
{lib}: let
  engine = import ./engine.nix {inherit lib;};

  # two sites (acme/beta) whose hosts advertise capabilities that appear nowhere in engine.nix.
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
          topology.routes = [
            {
              host = "web.acme.example";
              port = 80;
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
    # site-scoping: acme-web sees only acme hosts, never beta-cache-01
    {
      name = "site scoping excludes other sites";
      ok = f.hostsProviding "cache-node" == ["acme-cache-01" "acme-cache-02"];
    }
    # ipOf prefers internalIp when present, falls back to hostIp otherwise (cache-01 has both,
    # cache-02 only hostIp)
    {
      name = "ipsProviding prefers internalIp, falls back to hostIp";
      ok = f.ipsProviding "cache-node" == ["10.1.0.1" "10.0.0.2"];
    }
    # a novel single-provider capability resolves
    {
      name = "single-provider capability resolves";
      ok = f.ipProviding "metrics" == "10.1.0.1";
    }
    # a capability nobody provides -> null (single) / [] (set), not an error
    {
      name = "absent capability is null/empty, not an error";
      ok = f.ipProviding "nonexistent" == null && f.ipsProviding "nonexistent" == [];
    }
    # endpointFor: no HA node, single provider -> the single provider's IP
    {
      name = "endpointFor returns the single provider when no HA";
      ok =
        f.endpointFor {
          singleCap = "metrics";
          haCap = "metrics-ha";
          vipPath = ["lab" "whatever" "vip"];
        }
        == "10.1.0.1";
    }
    # routesInSite folds every same-site host's routes and pairs each with its resolved upstream
    # (ipOf, so cache-01's internal IP), and excludes other sites (beta's route never appears)
    {
      name = "routesInSite resolves upstreams and scopes to site";
      ok =
        map (r: {inherit (r) host upstream;}) f.routesInSite
        == [
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
    # publicUrlProviding: the single provider's single route becomes its https url
    {
      name = "publicUrlProviding returns the single provider's route url";
      ok = f.publicUrlProviding "metrics" == "https://cache1.acme.example";
    }
    # nobody provides it -> null, not an error
    {
      name = "publicUrlProviding is null for an absent capability";
      ok = f.publicUrlProviding "nonexistent" == null;
    }
    # more than one provider is ambiguous -> throws (tryEval catches it)
    {
      name = "publicUrlProviding throws on multiple providers";
      ok = !(builtins.tryEval (f.publicUrlProviding "cache-node")).success;
    }
    # the arity fix: a single-provider lookup with two providers is a config error, not a
    # silent null that would drop the service downstream
    {
      name = "ipProviding throws when two hosts claim a single-provider cap";
      ok = !(builtins.tryEval (f.ipProviding "cache-node")).success;
    }
    # singleCap == haCap with two providers is the normal HA state: fall through to the shared
    # VIP instead of throwing on the two single-cap matches
    {
      name = "endpointFor falls through to the VIP when the single cap is the HA cap";
      ok =
        f.endpointFor {
          singleCap = "cache-node";
          haCap = "cache-node";
          vipPath = ["lab" "cachevip" "vip"];
        }
        == "10.1.0.100";
    }
    # HA nodes advertising different VIPs is a config error, not a pick-one
    {
      name = "endpointFor throws on divergent VIPs";
      ok = let
        r = builtins.tryEval (f.endpointFor {
          singleCap = "cache-node";
          haCap = "cache-node";
          vipPath = ["lab" "badvip" "vip"];
        });
      in
        !r.success;
    }
  ];

  failures = lib.filter (c: !c.ok) checks;
in
  if failures == []
  then "ok"
  else throw "fleet-test failed: ${lib.concatMapStringsSep ", " (c: c.name) failures}"
