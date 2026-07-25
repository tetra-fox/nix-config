# VM integration tests for the fleet's runtime claims (failover, promotion, data
# survival) -- fleet-test.nix's fictional-fleet philosophy, one level up: the real service
# modules on a fictional site, in VMs. `just vm-test <name>` runs one locally; CI runs
# them per test in its own job.
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
}
