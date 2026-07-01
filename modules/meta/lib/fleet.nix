# fleet: capability-based cross-host service discovery for a NixOS fleet. stack-agnostic --
# it names no services and no sites; a host advertises capability strings via
# lab.topology.provides, and this resolves "which same-site host provides <cap>, and at what
# address" without any host naming another by name. a site is a hostname prefix (site-prefix.nix).
#
# THE INVARIANT (why this is a library and not just a fold over nixosConfigurations):
# a cross-host derive that reads a sibling's MODULE-DERIVED output eval-cycles the moment two
# hosts in a site each derive from the other (A resolves B's endpoint, B resolves A's, deadlock).
# so everything this engine reads across hosts is a plain INPUT: lab.topology.provides and
# lab.site.{hostIp,internalIp} -- flags/values a host sets directly, never computed from a peer.
# consumers that resolve a further cross-host VALUE (endpointFor's vipPath, or reading a
# published list) must keep to the same rule: the value read must be an input or a static
# default, never something derived from another host. the engine can't check a caller's vipPath
# points at an input, so that part of the invariant stays the consumer's contract -- but the
# engine itself only ever touches inputs, so a fleet that uses these primitives can't cycle.
{lib}: {
  # the flake's nixosConfigurations (or any {<name> = {config = ...};} attrset) + the host
  # doing the resolving. everything is scoped to that host's site.
  nixosConfigurations,
  hostName,
}: let
  sitePrefix = import ./site-prefix.nix {inherit lib;};

  mySite = sitePrefix hostName;

  isNixosHost = name: (nixosConfigurations.${name}.config.networking.hostName or null) != null;

  hostsInSite =
    lib.filter
    (name: isNixosHost name && sitePrefix nixosConfigurations.${name}.config.networking.hostName == mySite)
    (builtins.attrNames nixosConfigurations);

  # the address to REACH a host east-west: prefer its internal-VLAN IP so VM-to-VM links ride
  # the isolated fabric; fall back to the server-VLAN IP for a target with no internalIp.
  # reads lab.site.* directly (both are inputs) rather than scraping interfaces (ambiguous with
  # two NICs). a fleet without an internal VLAN just leaves internalIp null and gets hostIp.
  ipOf = name: let
    site = nixosConfigurations.${name}.config.lab.site or {};
  in
    if (site.internalIp or null) != null
    then site.internalIp
    else (site.hostIp or null);

  # generic: same-site hosts whose config satisfies `pred`. pred must read only inputs (see the
  # invariant above). everything below is a call to this with a capability check.
  hostsWhere = pred: lib.filter (name: pred nixosConfigurations.${name}.config) hostsInSite;

  # the IP of the single same-site host matching `pred`; null if zero or more than one (a caller
  # that needs exactly one asserts it). this is the seam an HA setup swaps for a VIP.
  ipWhere = pred: let
    hosts = hostsWhere pred;
  in
    if lib.length hosts == 1
    then ipOf (builtins.head hosts)
    else null;

  # the IPs of ALL same-site hosts matching `pred` (the set form of ipWhere).
  ipsWhere = pred: lib.filter (ip: ip != null) (map ipOf (hostsWhere pred));

  # the capability engine. a host's advertised caps (a plain input list); a predicate for "has
  # cap"; and the three fold forms over "who provides <cap>".
  provides = c: c.lab.topology.provides or [];
  hasCap = cap: c: builtins.elem cap (provides c);

  hostsProviding = cap: hostsWhere (hasCap cap);
  ipProviding = cap: ipWhere (hasCap cap);
  ipsProviding = cap: ipsWhere (hasCap cap);

  # the endpoint a client points at for an optionally-HA service: the single provider while one
  # exists (a live single server keeps the traffic until it's retired), else the floating VIP any
  # HA node advertises, else null. vipPath is an option path (e.g. ["lab" "caddy" "ha" "vip"]);
  # per the invariant it must point at a plain input option, not a derived value.
  endpointFor = {
    singleCap,
    haCap,
    vipPath,
  }: let
    single = ipProviding singleCap;
    vips =
      lib.unique (lib.filter (v: v != null)
        (map (name: lib.attrByPath vipPath null nixosConfigurations.${name}.config) (hostsProviding haCap)));
    vip =
      if vips != []
      then builtins.head vips
      else null;
  in
    if single != null
    then single
    else vip;
in {
  inherit sitePrefix mySite hostsInSite ipOf;
  inherit hostsWhere ipWhere ipsWhere;
  inherit hostsProviding ipProviding ipsProviding endpointFor;
  multiHost = lib.length hostsInSite > 1;
  myIp = ipOf hostName;
}
