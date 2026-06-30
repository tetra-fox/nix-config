# shared site-topology derivation. a neutral library (modules.lib.site-topology), imported
# by monitoring, logging, postgres, caddy, arr-stack, authentik -- it's fleet-wide service
# discovery, not a monitoring concern, so it lives under lib/ not any one service module.
# given a host's own config + the flake's nixosConfigurations, works out which other
# hosts share this host's site (by hostname prefix) and their declared addresses, so a
# module can find the same-site host running some service (monitoring server, db server)
# without a hand-maintained address list.
#
# IMPORTANT (no-recursion rule): predicates passed to hostsWhere / ipWhere must only read
# sibling INPUT attributes (networking.hostName, lab.site.{hostIp,internalIp},
# lab.<module>.server.enable -- plain flags the host sets). never read a sibling's
# module-DERIVED output (scrapeConfigs / firewall / bindAddr / the derived db endpoint) --
# that creates a real A<->B eval cycle once two hosts in a site each derive from the other.
{lib}: {
  nixosConfigurations,
  hostName,
}: let
  # site = hostname with the trailing -<role>-NN suffix stripped. single source in
  # site-prefix.nix (shared with flake.nix's colmena deploy tag).
  sitePrefix = import ./site-prefix.nix {inherit lib;};

  mySite = sitePrefix hostName;

  isNixosHost = name: (nixosConfigurations.${name}.config.networking.hostName or null) != null;

  hostsInSite =
    lib.filter
    (name: isNixosHost name && sitePrefix (nixosConfigurations.${name}.config.networking.hostName) == mySite)
    (builtins.attrNames nixosConfigurations);

  # the address to REACH a host for east-west traffic: prefer its isolated internal-VLAN
  # IP (10.10.0.x) when it has one, else its server-VLAN IP. so any VM-to-VM link between
  # two boxes on the internal VLAN rides the isolated fabric; an off-VLAN target (e.g. an
  # external appliance with no internalIp) is still reached on the server VLAN. reads the
  # lab.site.* options directly -- with two NICs, scraping interfaces is ambiguous.
  ipOf = name: let
    site = nixosConfigurations.${name}.config.lab.site or {};
  in
    if (site.internalIp or null) != null
    then site.internalIp
    else (site.hostIp or null);

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
  # the ingress host runs caddy. a backend whose proxy moved to this box binds its site IP
  # and opens its port to this IP only. services.caddy.enable is an INPUT signal.
  isEdgeHost = c: c.services.caddy.enable or false;
  # the storage host runs the NFS server (the media library). services.nfs.server.enable
  # is an INPUT signal. clients mount it at this host's internal IP.
  isStorageHost = c: c.services.nfs.server.enable or false;

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
  # the single ingress host's IP (caddy). a backend on another box opens its port to this
  # IP only (the reverse proxy is the sole legitimate client of an off-box backend).
  edgeHostIp = ipWhere isEdgeHost;
  # the single storage host's IP (NFS server) -- what the media host mounts the library
  # from. its NFS client is the media host (mediaHostIp), which today is the same box that
  # runs the arrs; store-01 scopes its export + firewall to that client IP.
  storageHostIp = ipWhere isStorageHost;
}
