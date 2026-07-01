# mesa's service-discovery POLICY: the named cross-host derives the mesa modules consume
# (dbEndpointIp, serverIp, arrDatabases, ...). the generic engine -- site membership, address
# resolution, the capability primitives, the no-recursion invariant -- lives in fleet.nix; this
# file is just the mesa capability vocabulary mapped onto it.
#
# adding a service = one lab.topology.provides line in that service's module + (if consumers need
# its address) one derive here. adding a HOST needs nothing here. the engine names nothing mesa;
# everything mesa-specific is below.
{lib}: args: let
  engine = import ./engine.nix {inherit lib;} args;
  inherit (engine) ipProviding ipsProviding hostsProviding endpointFor;
in
  engine
  // {
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

    # the arr db list, read off the single host advertising the arr capability. cycle-safe: the
    # published list is readOnly, defaulted from a static attrset, so it depends on no peer.
    arrDatabases = let
      hosts = hostsProviding "arr";
    in
      if hosts != []
      then args.nixosConfigurations.${builtins.head hosts}.config.lab.arrStack.databases
      else [];
  }
