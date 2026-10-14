# see README.md. everything read across hosts must be a plain input, never peer-derived, or two
# hosts deriving from each other eval-cycle. callers' `pred` and vipPath must keep the same rule
{lib}: {
  # any {<name> = {config = ...};} attrset
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

  # prefer internalIp so east-west traffic stays on the isolated VLAN. reads lab.site.* instead
  # of interfaces, which are ambiguous with two NICs
  ipOf = name: let
    site = nixosConfigurations.${name}.config.lab.site or {};
  in
    if (site.internalIp or null) != null
    then site.internalIp
    else (site.hostIp or null);

  hostsWhere = pred: lib.filter (name: pred nixosConfigurations.${name}.config) hostsInSite;

  # throws on >1 instead of returning null, or a consumer guarding on null silently skips the service
  ipWhere = pred: let
    hosts = hostsWhere pred;
  in
    if lib.length hosts == 0
    then null
    else if lib.length hosts == 1
    then ipOf (builtins.head hosts)
    else throw "fleet: site '${mySite}' has ${toString (lib.length hosts)} hosts matching a single-provider capability (${lib.concatStringsSep ", " hosts}); expected at most one";

  ipsWhere = pred: lib.filter (ip: ip != null) (map ipOf (hostsWhere pred));

  provides = c: c.lab.topology.provides or [];
  hasCap = cap: c: builtins.elem cap (provides c);

  hostsProviding = cap: hostsWhere (hasCap cap);
  ipProviding = cap: ipWhere (hasCap cap);
  ipsProviding = cap: ipsWhere (hasCap cap);

  # the declaring host is the upstream, so no route names an address
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

  # for a peer's url only, a service's own url derives from lab.site.domain. the result must not
  # feed config that reading routes forces. ambiguity throws, a null would drop config silently
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

  vipAmong = hosts: vipPath: capLabel: let
    vips =
      lib.unique (lib.filter (v: v != null)
        (map (name: lib.attrByPath vipPath null nixosConfigurations.${name}.config) hosts));
  in
    if lib.length vips > 1
    then throw "fleet: site '${mySite}' HA cap '${capLabel}' has ${toString (lib.length vips)} distinct VIPs at ${lib.concatStringsSep "." vipPath} (${lib.concatStringsSep ", " vips}); every HA node must declare the same one"
    else if vips != []
    then builtins.head vips
    else null;

  # one single-server host wins over the VIP. not ipProviding: two providers fall through to the
  # VIP instead of throwing
  resolveEndpoint = {
    singleHosts,
    haHosts,
    vipPath,
    capLabel,
  }:
    if lib.length singleHosts == 1
    then ipOf (builtins.head singleHosts)
    else vipAmong haHosts vipPath capLabel;

  # edge, dns: a lone provider is used directly, two resolve to the VIP
  haEndpointFor = {
    cap,
    vipPath,
  }: let
    hosts = hostsProviding cap;
  in
    resolveEndpoint {
      singleHosts = hosts;
      haHosts = hosts;
      inherit vipPath;
      capLabel = cap;
    };

  # postgres: separate single-server and HA caps
  optionalHaEndpointFor = {
    singleCap,
    haCap,
    vipPath,
  }:
    resolveEndpoint {
      singleHosts = hostsProviding singleCap;
      haHosts = hostsProviding haCap;
      inherit vipPath;
      capLabel = haCap;
    };
in {
  inherit sitePrefix mySite hostsInSite ipOf;
  inherit hostsWhere ipWhere ipsWhere;
  inherit hostsProviding ipProviding ipsProviding routesInSite publicUrlProviding;
  inherit haEndpointFor optionalHaEndpointFor;
  multiHost = lib.length hostsInSite > 1;
  myIp = ipOf hostName;
}
