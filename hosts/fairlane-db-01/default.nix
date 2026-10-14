# single postgres node on purpose, 2 proxmox nodes can't quorum a db
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
  ];

  lab = {
    site = {
      hostIp = "192.168.10.110";
      internalIp = "10.10.0.110";
      proxmoxParent = "plush";
    };

    postgres = {
      server.enable = true;
      admin.enable = true;
      openFirewall = true;
      # local dumps only, this host has no restic: covers a bad migration, not the disk dying
      backup.enable = true;
      extraAllowedCidrs = [config.lab.net.trustedCidr];

      roles = lib.optionalAttrs (topo.arrDbRole != null) {
        ${topo.arrDbRole.name} = {inherit (topo.arrDbRole) passwordSecret owns;};
      };
    };
  };

  system.stateVersion = "26.11";
}
