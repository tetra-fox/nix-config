{modules, ...}: {
  imports = [
    ./storage.nix

    modules.profiles.server.system

    modules.services.samba.system
    modules.desktop.avahi.system # mDNS so the SMB share shows up in Finder/file managers
    modules.toolsets.disk.system # smartctl etc for the passthrough drive
  ];

  networking.hostName = "fairlane-store-01";

  lab = {
    avahi.publish = true;

    site = {
      hostIp = "192.168.10.100";
      internalIp = "10.10.0.100";
      proxmoxParent = "pooltoy"; # the media passthrough disk lives on pooltoy
    };
  };

  system.stateVersion = "26.11";
}
