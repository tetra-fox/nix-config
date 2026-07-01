# given a host's config + the flake's nixosConfigurations, finds same-site hosts (by hostname
# prefix) and the address at which each advertises a capability.
#
# services self-register via lab.topology.provides (a plain list a module sets when its own
# enable flag is on), so this file names no services -- discovery is by capability string.
#
# IMPORTANT (no-recursion rule): lab.topology.provides and any attr a predicate reads must be
# a sibling INPUT (a flag a host sets), never a sibling's module-DERIVED output -- that creates
# an A<->B eval cycle once two hosts in a site each derive from the other.
{lib}: {
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

  # prefer a host's internal-VLAN IP so VM-to-VM links ride the isolated fabric; fall back to
  # the server-VLAN IP for off-VLAN targets (no internalIp).
  ipOf = name: let
    site = nixosConfigurations.${name}.config.lab.site or {};
  in
    if (site.internalIp or null) != null
    then site.internalIp
    else (site.hostIp or null);

  hostsWhere = pred: lib.filter (name: pred nixosConfigurations.${name}.config) hostsInSite;

  # null unless exactly one host matches (callers that need exactly one assert it).
  ipWhere = pred: let
    hosts = hostsWhere pred;
  in
    if lib.length hosts == 1
    then ipOf (builtins.head hosts)
    else null;

  ipsWhere = pred: lib.filter (ip: ip != null) (map ipOf (hostsWhere pred));

  provides = c: c.lab.topology.provides or [];
  hasCap = cap: c: builtins.elem cap (provides c);

  # same-site hosts advertising `cap`, its single provider's IP (null if 0 or >1), and all
  # providers' IPs.
  hostsProviding = cap: hostsWhere (hasCap cap);
  ipProviding = cap: ipWhere (hasCap cap);
  ipsProviding = cap: ipsWhere (hasCap cap);

  # the endpoint clients point at for an optionally-HA service: the single provider while one
  # exists (so a live single server keeps the traffic until it's retired), else the floating
  # VIP any HA node declares, else null. reads vipPath (a plain option) off the HA providers.
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
  inherit sitePrefix mySite hostsInSite ipOf hostsWhere ipWhere ipsWhere;
  inherit hostsProviding ipProviding ipsProviding;
  multiHost = lib.length hostsInSite > 1;
  myIp = ipOf hostName;

  serverIp = ipProviding "monitoring";
  # the monitoring-server hosts in this site (consumers assert exactly one)
  siteServers = hostsProviding "monitoring";
  authServerIp = ipProviding "auth-server";
  mediaHostIp = ipProviding "media";
  storageHostIp = ipProviding "storage";

  dbEndpointIp = endpointFor {
    singleCap = "db-server";
    haCap = "db-ha-node";
    vipPath = ["lab" "postgres" "ha" "vip"];
  };
  edgeEndpointIp = endpointFor {
    singleCap = "edge";
    haCap = "edge";
    vipPath = ["lab" "caddy" "ha" "vip"];
  };
  dnsEndpointIp = endpointFor {
    singleCap = "dns";
    haCap = "dns";
    vipPath = ["lab" "bind" "ha" "vip"];
  };

  # /32 of each client's hostIp; a netns client's traffic is SNAT'd to its hostIp
  # (lab.arrStack.netnsSnatHosts), so this covers it.
  dbClientCidrs = map (ip: "${ip}/32") (ipsProviding "db-client");
  # caddy proxies FROM its own box IP, not the VIP, so a backend must allow every edge box's
  # real IP.
  edgeHostIps = ipsProviding "edge";

  # the arr db list, read off the single host advertising the arr capability (readOnly,
  # defaulted from a static attrset, so reading it cross-host is cycle-safe).
  arrDatabases = let
    hosts = hostsProviding "arr";
  in
    if hosts != []
    then nixosConfigurations.${builtins.head hosts}.config.lab.arrStack.databases
    else [];
}
