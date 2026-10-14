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
