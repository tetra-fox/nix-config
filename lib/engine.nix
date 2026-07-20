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

  # the IP of the single same-site host matching `pred`. null means "nobody provides this" (a
  # legitimate absence a caller can guard on); more than one is a config error, not an absence, so
  # it throws rather than collapsing into the same null -- a consumer that guards on null would
  # otherwise silently skip the service when two hosts advertise the same cap. this is the seam an
  # HA setup swaps for a VIP.
  ipWhere = pred: let
    hosts = hostsWhere pred;
  in
    if lib.length hosts == 0
    then null
    else if lib.length hosts == 1
    then ipOf (builtins.head hosts)
    else throw "fleet: site '${mySite}' has ${toString (lib.length hosts)} hosts matching a single-provider capability (${lib.concatStringsSep ", " hosts}); expected at most one";

  # the IPs of ALL same-site hosts matching `pred` (the set form of ipWhere).
  ipsWhere = pred: lib.filter (ip: ip != null) (map ipOf (hostsWhere pred));

  # the capability engine. a host's advertised caps (a plain input list); a predicate for "has
  # cap"; and the three fold forms over "who provides <cap>".
  provides = c: c.lab.topology.provides or [];
  hasCap = cap: c: builtins.elem cap (provides c);

  hostsProviding = cap: hostsWhere (hasCap cap);
  ipProviding = cap: ipWhere (hasCap cap);
  ipsProviding = cap: ipsWhere (hasCap cap);

  # every route declared by a same-site host, each paired with the resolved upstream address of
  # the host that declared it (ipOf, so the internal-VLAN IP when present). lab.topology.routes is
  # a plain input, so this fold can't cycle. the edge host renders these into vhosts; the host that
  # declares a route is the upstream, so no route names an address.
  routesInSite =
    lib.concatMap
    (name: let
      ip = ipOf name;
      routes = nixosConfigurations.${name}.config.lab.topology.routes or [];
    in
      if routes != [] && ip == null
      then throw "fleet: host '${name}' declares caddy routes but has no resolvable address (neither lab.site.internalIp nor hostIp is set)"
      else map (r: r // {upstream = "${ip}:${toString r.port}";}) routes)
    hostsInSite;

  # the public https url of the single host advertising `cap`, from that host's declared route
  # (lab.topology.routes). lets a service resolve a PEER's public url without hardcoding the fqdn
  # (immich's oauth issuerUrl -> authentik). reads only plain inputs (provides + routes), so no
  # cycle -- BUT the consumer must not feed the result back into config that reading routes forces
  # (a service's OWN url is a local derive from lab.site.domain, not this). null when the provider
  # declares no public route; throws on >1 provider or >1 route, both ambiguities the caller can't
  # resolve -- a silent null there would drop a consumer's config (e.g. immich's oauth) with no
  # diagnostic.
  publicUrlProviding = cap: let
    hosts = hostsProviding cap;
  in
    if lib.length hosts == 0
    then null
    else if lib.length hosts > 1
    then throw "fleet: site '${mySite}' has ${toString (lib.length hosts)} hosts providing '${cap}'; publicUrlProviding expects exactly one"
    else let
      host = builtins.head hosts;
      routes = nixosConfigurations.${host}.config.lab.topology.routes or [];
    in
      if lib.length routes == 0
      then null
      else if lib.length routes == 1
      then "https://${(builtins.head routes).host}"
      else throw "fleet: '${cap}' provider '${host}' declares ${toString (lib.length routes)} routes; publicUrlProviding needs exactly one to name a public url";

  # the endpoint a client points at for an optionally-HA service: the single provider while one
  # exists (a live single server keeps the traffic until it's retired), else the floating VIP any
  # HA node advertises, else null. vipPath is an option path (e.g. ["lab" "caddy" "ha" "vip"]);
  # per the invariant it must point at a plain input option, not a derived value.
  #
  # the single lookup here does NOT reuse ipProviding: when singleCap == haCap (an HA-only service
  # like edge/dns, where the same hosts fill both roles), two providers is the normal HA state and
  # must fall through to the VIP, not throw. so a >1 single-cap match resolves to null (use the
  # VIP) rather than an error. a distinct singleCap (db-server) can still only have one host, but
  # that's enforced where it's read as a direct endpoint, not here.
  endpointFor = {
    singleCap,
    haCap,
    vipPath,
  }: let
    singleHosts = hostsProviding singleCap;
    single =
      if lib.length singleHosts == 1
      then ipOf (builtins.head singleHosts)
      else null;
    vips =
      lib.unique (lib.filter (v: v != null)
        (map (name: lib.attrByPath vipPath null nixosConfigurations.${name}.config) (hostsProviding haCap)));
    # every HA node must declare the same VIP; more than one distinct value is a config error, not
    # a pick-one situation. throw instead of silently taking whichever sorts first.
    vip =
      if lib.length vips > 1
      then throw "fleet: site '${mySite}' HA cap '${haCap}' has ${toString (lib.length vips)} distinct VIPs at ${lib.concatStringsSep "." vipPath} (${lib.concatStringsSep ", " vips}); every HA node must declare the same one"
      else if vips != []
      then builtins.head vips
      else null;
  in
    if single != null
    then single
    else vip;
in {
  inherit sitePrefix mySite hostsInSite ipOf;
  inherit hostsWhere ipWhere ipsWhere;
  inherit hostsProviding ipProviding ipsProviding endpointFor routesInSite publicUrlProviding;
  multiHost = lib.length hostsInSite > 1;
  myIp = ipOf hostName;
}
