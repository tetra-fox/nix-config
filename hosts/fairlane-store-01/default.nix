{modules, ...}: {
  imports = [
    ./storage.nix

    modules.profiles.server.system

    modules.services.restic.system
    modules.toolsets.disk.system
    modules.toolsets.hardware.system
    modules.toolsets.observe.system
  ];

  lab = {
    site = {
      hostIp = "192.168.10.100";
      internalIp = "10.10.0.100";
      proxmoxParent = "pooltoy";
    };

    backup.restic = {
      enable = true;
      bucket = "fairlane-12c7ab1b";
      # ext4, no snapshot, so restic reads the tree live. safe because HAOS uploads rename into
      # place. the media library is left out on purpose
      paths = ["/mnt/bigdisk/backup"];
    };
  };

  system.stateVersion = "26.11";
}
