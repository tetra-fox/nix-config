{
  username,
  modules,
  ...
}: {
  imports = [
    ./storage.nix
    ./monitoring.nix

    modules.platform.proxmox-vm.system
    modules.platform.disko.proxmox-vm
    modules.meta.profiles.server.system

    modules.services.samba.system
  ];

  networking.hostName = "mesa-store-01";
  lab.site.hostIp = "192.168.10.100";
  lab.site.internalIp = "10.10.0.100";

  system.stateVersion = "26.11";
}
