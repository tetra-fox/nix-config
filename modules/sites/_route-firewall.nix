# every route this host publishes gets a source-scoped accept for the site's edge hosts
# (caddy proxies from its own box IP, not the VIP), so a service that declares a route
# never hand-writes its ingress rule. a route whose upstream is reachable another way
# (podman-published ports, which DNAT before the input chain) opts out via its
# openFirewall flag. fleet-wide next to _options/_topology; a host with no routes or no
# edge (hara) contributes nothing.
{
  config,
  lib,
  fleet,
  topo,
  ...
}: let
  allowFrom = import fleet.nft {inherit lib;};
  ports = lib.unique (map (r: r.port) (lib.filter (r: r.openFirewall) config.lab.topology.routes));
in {
  networking.firewall.extraInputRules = lib.mkIf (ports != [] && topo.edgeHostIps != []) (
    allowFrom topo.edgeHostIps ports
  );
}
