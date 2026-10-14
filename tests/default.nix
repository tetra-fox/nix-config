# real service modules on a fictional site, in VMs. `just vm-test <name>` runs one
{
  pkgs,
  modules,
  fleet,
  caps,
}: let
  deps = {inherit modules fleet caps;};
in {
  edge-vip-failover = pkgs.testers.runNixOSTest (import ./edge-vip.nix deps);
  db-failover = pkgs.testers.runNixOSTest (import ./db-failover.nix deps);
  caddy-middleware = pkgs.testers.runNixOSTest (import ./caddy-middleware.nix deps);
}
