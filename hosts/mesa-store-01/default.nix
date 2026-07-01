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
    modules.desktop.avahi.system # mDNS so the SMB share shows up in Finder/file managers
  ];

  lab.avahi.publish = true;

  networking.hostName = "mesa-store-01";
  lab.site.hostIp = "192.168.10.100";
  lab.site.internalIp = "10.10.0.100";

  system.stateVersion = "26.11";
}
