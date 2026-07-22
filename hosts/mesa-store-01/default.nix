{modules, ...}: {
  imports = [
    ./storage.nix

    modules.profiles.server.system
    modules.platform.zfs.system # pool over the four passthrough drives

    modules.services.samba.system
    modules.services.restic.system # offsite backup of the small datasets to backblaze b2
    modules.desktop.avahi.system # mDNS so the SMB share shows up in Finder/file managers
    modules.toolsets.disk.system # smartctl etc for the passthrough drives
  ];

  lab = {
    avahi.publish = true;

    site.hostIp = "192.168.10.100";
    site.internalIp = "10.10.0.100";

    backup.restic = {
      enable = true;
      bucket = "mesa-512e3904";
      # each child dataset listed explicitly: a zfs snapshot of the parent
      # megamax/backup does NOT capture child datasets (verified: children appear
      # as empty dirs in the parent snapshot), so restic must snapshot each one.
      datasets = [
        # user facing general purpose samba shares
        {
          name = "megamax/store";
          mountpoint = "/mnt/megamax/store";
        }
        # backups
        {
          name = "megamax/backup/homeassistant";
          mountpoint = "/mnt/megamax/backup/homeassistant";
        }
        {
          name = "megamax/backup/timemachine";
          mountpoint = "/mnt/megamax/backup/timemachine";
        }
        # immich (backups, db, encoded-video, library, profile, thumbs, upload)
        {
          name = "megamax/immich";
          mountpoint = "/mnt/megamax/immich";
        }
        # TODO: megamax/backup/postgres maybe later uwu
      ];
    };
  };

  system.stateVersion = "26.11";
}
