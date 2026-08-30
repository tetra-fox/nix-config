{modules, ...}: {
  imports = [
    ./storage.nix

    modules.profiles.server.system

    modules.services.restic.system # offsite backup of /mnt/bigdisk/backup to backblaze b2
    modules.toolsets.disk.system # smartctl etc for the passthrough drive
    modules.toolsets.hardware.system # lspci, to confirm the guest sees the passthrough controller
    modules.toolsets.observe.system # iostat/iotop for disk-side latency
  ];

  lab = {
    site = {
      hostIp = "192.168.10.100";
      internalIp = "10.10.0.100";
      proxmoxParent = "pooltoy"; # the media passthrough disk lives on pooltoy
    };

    backup.restic = {
      enable = true;
      bucket = "fairlane-12c7ab1b";
      # paths, not datasets: this box is ext4, so there's no snapshot to read a frozen
      # tree from and restic backs the directory up live. everything under backup/ is
      # written by an upload that renames into place (HAOS tarballs, the postgres dump
      # script's .partial), so a run never ships a half-written file.
      #
      # the whole backup tree, not the individual children: the media library is
      # deliberately excluded (re-downloadable, and it dwarfs the disk), and anything
      # dropped in here later is covered without editing this list.
      paths = ["/mnt/bigdisk/backup"];
    };
  };

  system.stateVersion = "26.11";
}
