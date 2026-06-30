# mesa-auth-01: the mesa site's identity tier. runs the authentik SSO containers
# (server/worker/ldap outpost). the db lives on mesa-db-01 (reached via the dbServerIp
# derive); caddy finds this host via the authServerIp derive (lab.authentik.enable).
{
  username,
  modules,
  ...
}: {
  imports = [
    ./monitoring.nix

    modules.platform.proxmox-vm.system # qemu-guest + virtio initrd
    modules.platform.disko.proxmox-vm # boot-disk layout (scsi0)
    modules.meta.profiles.server.system

    modules.services.authentik.system
    modules.platform.sops.system
  ];

  lab.sops.secretsFile = ../../secrets/mesa-auth-01.yaml;

  networking.hostName = "mesa-auth-01";
  lab.site.hostIp = "192.168.10.120";
  lab.site.internalIp = "10.10.0.120"; # isolated internal VLAN (ens19)

  lab.authentik.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = ["wheel"];
  };

  system.stateVersion = "26.11";
}
