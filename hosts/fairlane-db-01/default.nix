# fairlane-db-01: SINGLE postgres node (not the mesa 3-node HA cluster). deliberate -- fairlane
# is the low-maintenance site, and 2 proxmox nodes can't honestly quorum a db anyway. the arrs
# connect here; the db list is derived from the arr host (fleet.topology arrDatabases), not
# hardcoded. no authentik at fairlane, so the only role is arr.
{
  config,
  modules,
  topo,
  ...
}: let
  arrDbs = topo.arrDatabases;
in {
  imports = [
    modules.profiles.server.system

    modules.services.postgres.system
    modules.platform.sops.system
  ];

  lab = {
    sops.secretsFile = ../../secrets/fairlane-db-01.yaml;

    site = {
      hostIp = "192.168.10.110";
      internalIp = "10.10.0.110";
      proxmoxParent = "plush";
    };

    postgres = {
      server.enable = true;
      admin.enable = true;
      openFirewall = true;
      # trusted-VLAN direct psql
      extraAllowedCidrs = [config.lab.net.trustedCidr];

      roles.arr = {
        passwordSecret = "arr/pg_pass";
        owns = arrDbs;
      };
    };
  };

  system.stateVersion = "26.11";
}
