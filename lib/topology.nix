# mesa's service-discovery POLICY: the named cross-host derives the mesa modules consume
# (dbEndpointIp, serverIp, arrDbRole, ...). the generic engine -- site membership, address
# resolution, the capability primitives, the no-recursion invariant -- lives in engine.nix; this
# file is just the mesa capability vocabulary mapped onto it.
#
# adding a service = one lab.topology.provides line in that service's module + (if consumers need
# its address) one derive here. adding a HOST needs nothing here. the engine names nothing mesa;
# everything mesa-specific is below. the capability names + vipPaths live in caps.nix so a provider
# and its consumer derive share one definition.
{lib}: args: let
  engine = import ./engine.nix {inherit lib;} args;
  caps = import ./caps.nix;
  inherit (engine) ipProviding ipsProviding hostsProviding hostsInSite haEndpointFor optionalHaEndpointFor publicUrlProviding;

  # read a value off the single host advertising `cap`, with ipProviding's arity rule:
  # nobody -> `absent` (a legitimate lack the caller guards on), two providers is a config
  # error, not a pick-one. per the invariant, `read` must return an input or a
  # static-defaulted (readOnly) option, never a peer-derived value.
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
    # one DNS A record per same-site host, at its own hostIp (the server-VLAN address, not
    # ipOf's internal-VLAN preference -- these answer clients reaching a host directly, e.g. a
    # Mac doing SSH/Samba/NFS, which live on the server VLAN, not the isolated internal fabric).
    # consumed by the site dns zone files, whose wildcard-to-edge-VIP record only covers HTTP(S);
    # without a specific record here a direct-protocol hostname silently falls through to it.
    hostRecords =
      lib.concatMapStrings
      (name: let
        hostIp = args.nixosConfigurations.${name}.config.lab.site.hostIp or null;
      in
        lib.optionalString (hostIp != null) "${name} IN A ${hostIp}\n")
      hostsInSite;

    serverIp = ipProviding caps.monitoring.name;
    # the monitoring-server hosts in this site (consumers assert exactly one)
    siteServers = hostsProviding caps.monitoring.name;
    authServerIp = ipProviding caps.authServer.name;
    mediaHostIp = ipProviding caps.media.name;
    storageHostIp = ipProviding caps.storage.name;
    immichHostIp = ipProviding caps.immich.name;

    # authentik's public url (https://auth.<site>), derived from its declared route. the consumer
    # is immich's oauth issuerUrl: immich resolves authentik's url from the registry instead of
    # restating the fqdn. safe (cross-service, not fed back into authentik's own config).
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

    # /32 of each client's hostIp; a netns client's traffic is SNAT'd to its hostIp
    # (lab.arrStack.netnsSnatHosts), so this covers it.
    dbClientCidrs = map (ip: "${ip}/32") (ipsProviding caps.dbClient.name);
    # caddy proxies FROM its own box IP, not the VIP, so a backend must allow every edge box's
    # real IP.
    edgeHostIps = ipsProviding caps.edge.name;

    # the arr postgres role spec {name, passwordSecret, owns}, read off the arr host so the
    # db host restates none of it. cycle-safe: the published value is readOnly, defaulted
    # from static attrsets.
    arrDbRole = inputOfProviding caps.arr.name (c: c.lab.arrStack.dbRole) null;

    # the immich host's pinned uid (lab.immich.uid, a static-defaulted input, so cycle-safe).
    # the store box owns the immich dataset dirs with it so NFS writes (numeric uids, no
    # squash) land as immich on both ends.
    immichUid = inputOfProviding caps.immich.name (c: c.lab.immich.uid) null;

    # authentik's http port (lab.authentik.port, readOnly), for caddy's forward-auth
    # upstream; pairs with authServerIp
    authServerPort = inputOfProviding caps.authServer.name (c: c.lab.authentik.port) null;
  }
