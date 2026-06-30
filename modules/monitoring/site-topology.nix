# shared site-topology derivation used by the monitoring, logging, and postgres modules.
# given a host's own config + the flake's nixosConfigurations, works out which other
# hosts share this host's site (by hostname prefix) and their declared static IPs, so a
# module can find the same-site host running some service (monitoring server, db server)
# without a hand-maintained address list.
#
# IMPORTANT (no-recursion rule): predicates passed to hostsWhere / ipWhere must only read
# sibling INPUT attributes (networking.hostName, networking.interfaces.*.ipv4.addresses,
# lab.<module>.server.enable -- plain flags the host sets). never read a sibling's
# module-DERIVED output (scrapeConfigs / firewall / bindAddr / the derived db endpoint) --
# that creates a real A<->B eval cycle once two hosts in a site each derive from the other.
{lib}: {
  nixosConfigurations,
  hostName,
}: let
  # site = hostname with the trailing -<role>-NN suffix stripped.
  # mesa-svc-01 -> mesa, mesa-store-01 -> mesa, fairlane-svc-01 -> fairlane, hara -> hara.
  # the role list must cover every fleet tier or that host lands in a site of its own and
  # the derive misses it (kept in sync with the same helper in flake.nix).
  sitePrefix = name: let
    m = builtins.match "(.+)-(svc|mon|store|db|auth|jelly|edge)-[0-9]+" name;
  in
    if m == null
    then name
    else builtins.head m;

  mySite = sitePrefix hostName;

  isNixosHost = name: (nixosConfigurations.${name}.config.networking.hostName or null) != null;

  hostsInSite =
    lib.filter
    (name: isNixosHost name && sitePrefix (nixosConfigurations.${name}.config.networking.hostName) == mySite)
    (builtins.attrNames nixosConfigurations);

  ipOf = name: let
    ifaces = nixosConfigurations.${name}.config.networking.interfaces or {};
    addrs = lib.concatMap (i: i.ipv4.addresses or []) (builtins.attrValues ifaces);
  in
    if addrs == []
    then null
    else (builtins.head addrs).address;

  # generic: same-site hosts whose config satisfies `pred` (pred gets the host's config).
  # every "find the host running X in my site" derive is a call to this with X's flag.
  hostsWhere = pred: lib.filter (name: pred nixosConfigurations.${name}.config) hostsInSite;

  # the IP of the single same-site host satisfying `pred`; null if zero or more than one
  # (callers that need exactly one assert it). this is the address a client points at to
  # reach that service -- the seam an HA setup later swaps for a VIP/leader endpoint.
  ipWhere = pred: let
    hosts = hostsWhere pred;
  in
    if lib.length hosts == 1
    then ipOf (builtins.head hosts)
    else null;

  # the IPs of ALL same-site hosts satisfying `pred` (the set form of ipWhere). for the
  # inverse of an endpoint derive: a server building its allow-list of clients.
  ipsWhere = pred: lib.filter (ip: ip != null) (map ipOf (hostsWhere pred));

  # named predicates, one per service flag. keeping them here documents which INPUT flag
  # each derive keys on (and keeps the no-recursion rule auditable in one place).
  isMonitoringServer = c: c.lab.monitoring.server.enable or false;
  isDbServer = c: c.lab.postgres.server.enable or false;
  isDbClient = c: c.lab.postgres.client.enable or false;
  isAuthServer = c: c.lab.authentik.enable or false;
  # the media host runs jellyfin (+ nowplaying alongside it). services.jellyfin.enable is
  # an INPUT (set directly in the jellyfin module), so reading it keeps the no-recursion rule.
  isMediaHost = c: c.services.jellyfin.enable or false;

  siteServers = hostsWhere isMonitoringServer;
in {
  inherit sitePrefix mySite hostsInSite ipOf hostsWhere ipWhere ipsWhere siteServers;
  multiHost = lib.length hostsInSite > 1;
  myIp = ipOf hostName;
  # the single monitoring server's IP (null if 0 or >1 -- caller asserts exactly one)
  serverIp = ipWhere isMonitoringServer;
  # the single postgres server's IP -- what arr/authentik clients point at. today a lone
  # db-NN; an HA setup swaps the flag's holder (or this derive) for the floating endpoint.
  dbServerIp = ipWhere isDbServer;
  # the IPs of every same-site postgres client (lab.postgres.client.enable) -- the inverse
  # of dbServerIp: the db server folds these into its pg_hba allow-list. assumes a client
  # reaches the db FROM its declared hostIp (true for direct LAN clients, and for a netns
  # client whose traffic is SNAT'd to its hostIp via lab.arrStack.netnsSnatHosts).
  dbClientCidrs = map (ip: "${ip}/32") (ipsWhere isDbClient);
  # the single authentik host's IP -- what caddy reverse-proxies auth.<site> + forward_auth to.
  authServerIp = ipWhere isAuthServer;
  # the single media host's IP (jellyfin + nowplaying) -- caddy proxies jellyfin.<site>
  # and np.<site> here. today the same box as the arr stack.
  mediaHostIp = ipWhere isMediaHost;
}
