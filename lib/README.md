# fleet: capability-based cross-host discovery

`engine.nix` is a stack-agnostic engine for "which host in my site provides service X, and at
what address" -- without any host naming another by name. `topology.nix` is the mesa
*policy* layer on top of it (the named derives mesa modules consume). The split is the point:
the engine names no services and no sites, so it's the reusable part; the mesa vocabulary is a
thin consumer.

## The model

A host advertises capability strings:

```nix
# in a service module, gated on its own enable flag (a plain input):
config.lab.topology.provides = ["db-server"];
```

Anything resolves providers by capability, scoped to the same site (a site is the hostname
prefix -- `mesa-db-01` and `mesa-svc-01` share site `mesa`):

```nix
engine = import ./engine.nix { inherit lib; } { inherit nixosConfigurations; hostName; };
engine.ipProviding "db-server"      # the single provider's IP (null if 0 or >1)
engine.ipsProviding "db-client"     # every provider's IP
engine.hostsProviding "db-ha-node"  # the provider host names
engine.optionalHaEndpointFor {      # the address for an optionally-HA service:
  singleCap = "db-server";          #   the single provider while one exists,
  haCap = "db-ha-node";             #   else the floating VIP the HA nodes advertise
  vipPath = ["lab" "postgres" "ha" "vip"];
}
```

Adding a service = one `provides` line in its module (+ a derive in the policy layer if
consumers need its address). Adding a *host* needs nothing. Adding a new *capability type* needs
no engine edit -- that's the test that this is a library, enforced by `fleet-test.nix`.

## THE INVARIANT (why this is a library, not a fold)

A cross-host derive that reads a sibling's **module-derived output** eval-cycles the moment two
hosts in a site each derive from the other (A resolves B's endpoint, B resolves A's -> deadlock).
So everything the engine reads across hosts is a plain **input**: `lab.topology.provides` and
`lab.site.{hostIp,internalIp}` -- values a host sets directly, never computed from a peer.

Consumers must keep the rule: any further cross-host value you resolve (an `endpointFor` vipPath,
or reading a published list) must point at an input or a static default, never a peer-derived
value. The engine can't check a caller's `vipPath`, so that half stays a contract -- but the
engine itself only ever touches inputs, so a fleet built on these primitives can't cycle.

## Reusing it elsewhere

`engine.nix` depends only on `lib` + `site-prefix.nix` (both mesa-free). To use it in another
repo: copy those two files, have hosts set `lab.topology.provides` + `lab.site.{hostIp,
internalIp}` (or adapt `ipOf`/`provides` to your option names), and write your own policy layer
of named derives. No internal VLAN? Leave `internalIp` null and `ipOf` returns `hostIp`.

`fleet-test.nix` is the generalization guarantee: a fictional non-mesa fleet with a capability
the engine never heard of. If it ever needs an engine change to pass, the engine stopped being
generic.
