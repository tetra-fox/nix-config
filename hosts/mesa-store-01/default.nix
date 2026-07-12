{modules, ...}: {
  imports = [
    ./storage.nix

    modules.profiles.server.system
    modules.platform.zfs.system # pool over the four passthrough drives

    modules.services.samba.system
    modules.desktop.avahi.system # mDNS so the SMB share shows up in Finder/file managers
    modules.toolsets.disk.system # smartctl etc for the passthrough drives
  ];

  networking.hostName = "mesa-store-01";

  lab = {
    avahi.publish = true;

    site.hostIp = "192.168.10.100";
    site.internalIp = "10.10.0.100";
  };

  system.stateVersion = "26.11";
}
