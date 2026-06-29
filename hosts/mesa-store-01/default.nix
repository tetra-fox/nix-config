# mesa-store-01: the mesa site's storage tier. owns the media disk and serves it over
# NFS (to the service VMs) + SMB (to people). the floor of the dependency DAG -- svc-01
# and jelly-01 mount their library from here -- so it's kept deliberately minimal.
{
  username,
  modules,
  ...
}: {
  imports = [
    ./storage.nix

    modules.proxmox-vm.system # this host is a proxmox VM (qemu-guest + virtio initrd)
    modules.disko.proxmox-vm # boot-disk layout (scsi0); the media disk is separate
    modules.profiles.server.system

    modules.samba.system
  ];

  # no modules.sops.system: store-01 has no per-host secrets (NFS needs none, SMB uses
  # local passwd auth set out-of-band). add it back with a secrets file if that changes.

  # site facts (VLAN/gateway/DNS layout, siteData root, topology parent) come from
  # the `mesa` tag (modules/sites/mesa.nix). this host just declares its own IP.
  networking.hostName = "mesa-store-01";
  lab.site.hostIp = "192.168.10.222";

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = ["wheel"];
  };

  system.stateVersion = "26.11";
}
