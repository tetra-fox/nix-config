# fairlane-db-01: SINGLE postgres node (not the mesa 3-node HA cluster). deliberate -- fairlane
# is the low-maintenance site, and 2 proxmox nodes can't honestly quorum a db anyway. the arrs
# connect here; the whole arr role spec is derived from the arr host (topo.arrDbRole), not
# hardcoded. no authentik at fairlane, so that's the only role.
{
  config,
  lib,
  modules,
  topo,
  ...
}: {
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

      # the arr role spec comes off the arr host via the registry
      roles = lib.optionalAttrs (topo.arrDbRole != null) {
        ${topo.arrDbRole.name} = {inherit (topo.arrDbRole) passwordSecret owns;};
      };
    };
  };

  system.stateVersion = "26.11";
}
