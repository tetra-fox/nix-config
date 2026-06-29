# shared site-topology derivation used by both the monitoring and logging modules.
# given a host's own config + the flake's nixosConfigurations, works out which other
# hosts share this host's site (by hostname prefix) and their declared static IPs, so
# the server can auto-build scrape targets / the agent can find its server.
#
# IMPORTANT (no-recursion rule): only ever reads sibling INPUT attributes
# (networking.hostName, networking.interfaces.*.ipv4.addresses, lab.monitoring.server.enable).
# never read a sibling's monitoring-DERIVED output (scrapeConfigs / firewall / bindAddr) --
# that creates a real A<->B cycle once two servers exist.
{lib}: {
  nixosConfigurations,
  hostName,
}: let
  # site = hostname with the trailing -<role>-NN suffix stripped.
  # mesa-svc-01 -> mesa, mesa-store-01 -> mesa, fairlane-svc-01 -> fairlane, hara -> hara.
  # the role list must cover every fleet tier or that host lands in a site of its own and
  # the monitoring derive misses it (kept in sync with the same helper in flake.nix).
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

  serverEnabledOn = name: nixosConfigurations.${name}.config.lab.monitoring.server.enable or false;

  siteServers = lib.filter serverEnabledOn hostsInSite;
in {
  inherit sitePrefix mySite hostsInSite ipOf siteServers;
  multiHost = lib.length hostsInSite > 1;
  myIp = ipOf hostName;
  # the single site server's IP (null if 0 or >1 -- caller asserts exactly one)
  serverIp =
    if lib.length siteServers == 1
    then ipOf (builtins.head siteServers)
    else null;
}
