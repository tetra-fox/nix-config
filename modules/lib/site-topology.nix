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
  # a node in the HA postgres cluster (Patroni). distinct from isDbServer: an HA node sets
  # ha.enable, not server.enable, so the single-server derive (ipWhere isDbServer) returns
  # null when the site is HA -- dbEndpointIp short-circuits to the VIP before that matters.
  isDbHaNode = c: c.lab.postgres.ha.enable or false;
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
  # the resolver host runs bind. services.bind.enable is an INPUT signal, set in the bind
  # module. the keepalived module folds over these to build its VIP peer list.
  isDnsHost = c: c.services.bind.enable or false;

  siteServers = hostsWhere isMonitoringServer;

  # the db endpoint derives reference each other (dbEndpointIp picks between dbServerIp and
  # dbHaVip), so they're let-bindings here rather than sibling attrs in the output set (an
  # attr can't read a sibling attr by bare name). exposed in the `in` set below.
  dbServerIp = ipWhere isDbServer;
  dbHaVip = let
    vips = lib.unique (lib.filter (v: v != null)
      (map (name: nixosConfigurations.${name}.config.lab.postgres.ha.vip or null) (hostsWhere isDbHaNode)));
  in
    if vips != []
    then builtins.head vips
    else null;
  # the VIP only takes over once the HA cluster is the LIVE authority: an HA node exists AND
  # no single-server node remains. while db-01 is still server.enable and db-02/03 are stood
  # up as HA, clients stay on db-01 (dbServerIp); the instant db-01 drops server.enable for
  # ha.enable, dbServerIp goes null and the VIP takes over.
  dbEndpointIp =
    if dbHaVip != null && dbServerIp == null
    then dbHaVip
    else dbServerIp;

  # edge derives, same shape as the db ones. edgeHostIp is the single ingress host (null with
  # >1 edge box). edgeHaVip is the floating ingress VIP any edge host declares. edgeEndpointIp
  # is what the world reaches edge at: the VIP when an edge host runs HA, else the single host.
  edgeHostIp = ipWhere isEdgeHost;
  edgeHaVip = let
    vips = lib.unique (lib.filter (v: v != null)
      (map (name: nixosConfigurations.${name}.config.lab.caddy.ha.vip or null) (hostsWhere isEdgeHost)));
  in
    if vips != []
    then builtins.head vips
    else null;
  edgeEndpointIp =
    if edgeHaVip != null
    then edgeHaVip
    else edgeHostIp;

  # dns derives, same shape. dnsHostIp is the single resolver host (null with >1 box).
  # dnsHaVip is the floating resolver VIP any dns host declares. dnsEndpointIp is what
  # points-at-the-resolver should use: the VIP when HA is live, else the single host.
  dnsHostIp = ipWhere isDnsHost;
  dnsHaVip = let
    vips = lib.unique (lib.filter (v: v != null)
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
  # predicates exported for modules that fold over a class of hosts: isDbHaNode (the postgres
  # module builds etcd/patroni/haproxy peer lists), isEdgeHost (the caddy module builds the
  # keepalived peer list + priority from the edge hosts).
  inherit isDbHaNode isEdgeHost isDnsHost;
  multiHost = lib.length hostsInSite > 1;
  myIp = ipOf hostName;
  # the single monitoring server's IP (null if 0 or >1 -- caller asserts exactly one)
  serverIp = ipWhere isMonitoringServer;
  # the single postgres server's IP (non-HA), the HA VIP, and the endpoint clients actually
  # point at (the VIP when HA is the live authority, else the single server). defined as
  # let-bindings above because they reference each other; see there for the cutover logic.
  inherit dbServerIp dbHaVip dbEndpointIp;
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
  # the single ingress host's IP (caddy, null with >1), the floating ingress VIP, and the
  # endpoint the world reaches edge at (vip when HA, else the single host). let-bindings above.
  inherit edgeHostIp edgeHaVip edgeEndpointIp;
  # the single resolver host's IP (null with >1), the floating resolver VIP, and the endpoint
  # that points-at-the-resolver should use (the VIP when HA, else the single host). the router's
  # upstream DNS targets dnsEndpointIp. let-bindings above (same reason as the edge derives).
  inherit dnsHostIp dnsHaVip dnsEndpointIp;
  # the IPs of EVERY edge host (plural) -- for a backend that allow-lists caddy as a source.
  # caddy proxies FROM its own box IP (not the VIP, which is a destination), so a backend with
  # two edge boxes must allow both real IPs. this is the plural form of edgeHostIp.
  edgeHostIps = ipsWhere isEdgeHost;
  # the single storage host's IP (NFS server) -- what the media host mounts the library
  # from. its NFS client is the media host (mediaHostIp), which today is the same box that
  # runs the arrs; store-01 scopes its export + firewall to that client IP.
  storageHostIp = ipWhere isStorageHost;
}
