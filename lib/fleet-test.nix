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
        };
      };
    };
    acme-cache-02 = {
      config = {
        networking.hostName = "acme-cache-02";
        lab = {
          site.hostIp = "10.0.0.2";
          topology.provides = ["cache-node"];
        };
      };
    };
    acme-web-01 = {
      config = {
        networking.hostName = "acme-web-01";
        lab = {
          site.hostIp = "10.0.0.3";
          topology.provides = ["web"];
        };
      };
    };
    beta-cache-01 = {
      config = {
        networking.hostName = "beta-cache-01";
        lab = {
          site.hostIp = "10.9.9.1";
          topology.provides = ["cache-node"];
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
  ];

  failures = lib.filter (c: !c.ok) checks;
in
  if failures == []
  then "ok"
  else throw "fleet-test failed: ${lib.concatMapStringsSep ", " (c: c.name) failures}"
