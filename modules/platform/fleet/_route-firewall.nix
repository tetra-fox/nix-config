{
  config,
  lib,
  fleet,
  topo,
  ...
}: let
  ports = lib.unique (map (r: r.port) (lib.filter (r: r.openFirewall) config.lab.topology.routes));
in {
  networking.firewall.extraInputRules = lib.mkIf (ports != [] && topo.edgeHostIps != []) (
    fleet.allow-from topo.edgeHostIps ports
  );
}
