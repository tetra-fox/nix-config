# given a host's config + the flake's nixosConfigurations, finds same-site hosts (by hostname
# prefix) and their declared addresses.
#
# IMPORTANT (no-recursion rule): predicates passed to hostsWhere / ipWhere must only read
# sibling INPUT attributes (flags a host sets), never a sibling's module-DERIVED output
# (scrapeConfigs / firewall / bindAddr / the derived db endpoint) -- that creates an A<->B
# eval cycle once two hosts in a site each derive from the other.
{lib}: {
  nixosConfigurations,
  hostName,
}: let
  sitePrefix = import ./site-prefix.nix {inherit lib;};

  mySite = sitePrefix hostName;

  isNixosHost = name: (nixosConfigurations.${name}.config.networking.hostName or null) != null;

  hostsInSite =
    lib.filter
    (name: isNixosHost name && sitePrefix (nixosConfigurations.${name}.config.networking.hostName) == mySite)
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

  isMonitoringServer = c: c.lab.monitoring.server.enable or false;
  isDbServer = c: c.lab.postgres.server.enable or false;
  isDbClient = c: c.lab.postgres.client.enable or false;
  # HA nodes set ha.enable, not server.enable, so isDbServer misses them; dbEndpointIp picks
  # between the two.
  isDbHaNode = c: c.lab.postgres.ha.enable or false;
  isAuthServer = c: c.lab.authentik.enable or false;
  isMediaHost = c: c.services.jellyfin.enable or false;
  isEdgeHost = c: c.services.caddy.enable or false;
  isStorageHost = c: c.services.nfs.server.enable or false;
  isDnsHost = c: c.services.bind.enable or false;
  # lab.arrStack.databases is readOnly, defaulted from a static attrset, so reading it cross-host
  # is cycle-safe.
  isArrHost = c: (c.lab.arrStack.databases or []) != [];

  arrHosts = hostsWhere isArrHost;
  arrDatabases =
    if arrHosts != []
    then nixosConfigurations.${builtins.head arrHosts}.config.lab.arrStack.databases
    else [];

  siteServers = hostsWhere isMonitoringServer;

  # dbEndpointIp reads dbServerIp/dbHaVip, so these are let-bindings, not sibling output attrs
  # (an attr can't read a sibling by bare name).
  dbServerIp = ipWhere isDbServer;
  dbHaVip = let
    vips =
      lib.unique (lib.filter (v: v != null)
        (map (name: nixosConfigurations.${name}.config.lab.postgres.ha.vip or null) (hostsWhere isDbHaNode)));
  in
    if vips != []
    then builtins.head vips
    else null;
  # the VIP takes over only once no single-server node remains, so clients stay on the old
  # db-01 until it drops server.enable for ha.enable.
  dbEndpointIp =
    if dbHaVip != null && dbServerIp == null
    then dbHaVip
    else dbServerIp;

  edgeHostIp = ipWhere isEdgeHost;
  edgeHaVip = let
    vips =
      lib.unique (lib.filter (v: v != null)
        (map (name: nixosConfigurations.${name}.config.lab.caddy.ha.vip or null) (hostsWhere isEdgeHost)));
  in
    if vips != []
    then builtins.head vips
    else null;
  edgeEndpointIp =
    if edgeHaVip != null
    then edgeHaVip
    else edgeHostIp;

  dnsHostIp = ipWhere isDnsHost;
  dnsHaVip = let
    vips =
      lib.unique (lib.filter (v: v != null)
        (map (name: nixosConfigurations.${name}.config.lab.bind.ha.vip or null) (hostsWhere isDnsHost)));
  in
    if vips != []
    then builtins.head vips
    else null;
  dnsEndpointIp =
    if dnsHaVip != null
    then dnsHaVip
    else dnsHostIp;
in {
  inherit sitePrefix mySite hostsInSite ipOf hostsWhere ipWhere ipsWhere siteServers;
  inherit isDbHaNode isEdgeHost isDnsHost;
  multiHost = lib.length hostsInSite > 1;
  myIp = ipOf hostName;
  serverIp = ipWhere isMonitoringServer;
  inherit dbServerIp dbHaVip dbEndpointIp;
  # /32 of each client's hostIp; a netns client's traffic is SNAT'd to its hostIp
  # (lab.arrStack.netnsSnatHosts), so this covers it.
  dbClientCidrs = map (ip: "${ip}/32") (ipsWhere isDbClient);
  authServerIp = ipWhere isAuthServer;
  mediaHostIp = ipWhere isMediaHost;
  inherit edgeHostIp edgeHaVip edgeEndpointIp;
  inherit dnsHostIp dnsHaVip dnsEndpointIp;
  # caddy proxies FROM its own box IP, not the VIP, so a backend must allow every edge box's
  # real IP.
  edgeHostIps = ipsWhere isEdgeHost;
  storageHostIp = ipWhere isStorageHost;
  inherit arrDatabases;
}
