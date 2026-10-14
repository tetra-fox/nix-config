# mesa's derives over the generic engine. a new service needs a provides line in its module, plus a
# derive here only if something consumes its address. a new host needs nothing here
{lib}: args: let
  engine = import ./engine.nix {inherit lib;} args;
  caps = import ./caps.nix;
  inherit (engine) ipProviding ipsProviding hostsProviding hostsInSite haEndpointFor optionalHaEndpointFor publicUrlProviding;

  # none -> `absent`, several -> error. `read` must return an input or a static-defaulted
  # readOnly option, never a peer-derived value
  inputOfProviding = cap: read: absent: let
    hosts = hostsProviding cap;
  in
    if hosts == []
    then absent
    else if lib.length hosts == 1
    then read args.nixosConfigurations.${builtins.head hosts}.config
    else throw "fleet: site '${engine.mySite}' has ${toString (lib.length hosts)} hosts providing '${cap}'; expected at most one";
in
  engine
  // {
    # hostIp, not ipOf's internal-VLAN pick: direct ssh/smb/nfs clients are on the server VLAN.
    # without these, host names fall through to the zone's wildcard-to-edge record
    hostRecords =
      lib.concatMapStrings
      (name: let
        hostIp = args.nixosConfigurations.${name}.config.lab.site.hostIp or null;
      in
        lib.optionalString (hostIp != null) "${name} IN A ${hostIp}\n")
      hostsInSite;

    serverIp = ipProviding caps.monitoring.name;
    # consumers assert exactly one
    siteServers = hostsProviding caps.monitoring.name;
    authServerIp = ipProviding caps.authServer.name;
    mediaHostIp = ipProviding caps.media.name;
    storageHostIp = ipProviding caps.storage.name;
    immichHostIp = ipProviding caps.immich.name;

    # for immich's oauth issuerUrl. safe because it never feeds authentik's own config
    authServerUrl = publicUrlProviding caps.authServer.name;

    dbEndpointIp = optionalHaEndpointFor {
      singleCap = caps.dbServer.name;
      haCap = caps.dbHaNode.name;
      vipPath = caps.dbHaNode.vipPath;
    };
    edgeEndpointIp = haEndpointFor {
      cap = caps.edge.name;
      vipPath = caps.edge.vipPath;
    };
    dnsEndpointIp = haEndpointFor {
      cap = caps.dns.name;
      vipPath = caps.dns.vipPath;
    };

    # netns clients are SNAT'd to their hostIp (lab.arrStack.netnsSnatHosts)
    dbClientCidrs = map (ip: "${ip}/32") (ipsProviding caps.dbClient.name);
    # caddy proxies from its own box IP, not the VIP
    edgeHostIps = ipsProviding caps.edge.name;

    # any of them can be the patroni leader running the dump
    dbHaNodeIps = ipsProviding caps.dbHaNode.name;

    # cycle-safe: readOnly, defaulted from static attrsets
    arrDbRole = inputOfProviding caps.arr.name (c: c.lab.arrStack.dbRole) null;

    # the store box owns immich's dataset dirs with this uid, NFS writes are unsquashed
    immichUid = inputOfProviding caps.immich.name (c: c.lab.immich.uid) null;

    # for caddy's forward-auth upstream
    authServerPort = inputOfProviding caps.authServer.name (c: c.lab.authentik.port) null;
  }
