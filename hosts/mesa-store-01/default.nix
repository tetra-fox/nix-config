{modules, ...}: {
  imports = [
    ./storage.nix

    modules.profiles.server.system
    modules.platform.zfs.system # pool over the four passthrough drives
    modules.platform.sops.system # b2 + restic credentials for the offsite backup

    modules.services.samba.system
    modules.services.restic.system # offsite backup of the small datasets to backblaze b2
    modules.desktop.avahi.system # mDNS so the SMB share shows up in Finder/file managers
    modules.toolsets.disk.system # smartctl etc for the passthrough drives
  ];

  lab = {
    avahi.publish = true;

    sops.secretsFile = ../../secrets/mesa-store-01.yaml;

    site.hostIp = "192.168.10.100";
    site.internalIp = "10.10.0.100";

    backup.restic = {
      enable = true;
      bucket = "mesa-512e3904";
      # each child dataset listed explicitly: a zfs snapshot of the parent
      # megamax/backup does NOT capture child datasets (verified: children appear
      # as empty dirs in the parent snapshot), so restic must snapshot each one.
      datasets = [
        {
          name = "megamax/store";
          mountpoint = "/mnt/megamax/store";
        }
        {
          name = "megamax/backup/homeassistant";
          mountpoint = "/mnt/megamax/backup/homeassistant";
        }
        {
          name = "megamax/backup/timemachine";
          mountpoint = "/mnt/megamax/backup/timemachine";
        }
        # immich writes library/ + its pg_dumpall backups/ under here, so one snapshot
        # captures the photos and a consistent db dump together
        {
          name = "megamax/immich";
          mountpoint = "/mnt/megamax/immich";
        }
        # megamax/backup/postgres added with the pgBackRest/postgres-backup task
      ];
    };
  };

  system.stateVersion = "26.11";
}
