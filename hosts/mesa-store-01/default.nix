{modules, ...}: {
  imports = [
    ./storage.nix

    modules.profiles.server.system
    modules.platform.zfs.system

    modules.services.samba.system
    modules.services.restic.system
    modules.desktop.avahi.system
    modules.toolsets.disk.system
    modules.toolsets.hardware.system
    modules.toolsets.observe.system
    modules.hardware.smartctl.system
  ];

  lab = {
    avahi.publish = true;

    site.hostIp = "192.168.10.100";
    site.internalIp = "10.10.0.100";

    backup.restic = {
      enable = true;
      bucket = "mesa-512e3904";
      # a snapshot of megamax/backup doesn't capture its child datasets
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
        {
          name = "megamax/immich";
          mountpoint = "/mnt/megamax/immich";
        }
        {
          name = "megamax/backup/postgres";
          mountpoint = "/mnt/megamax/backup/postgres";
        }
      ];
    };
  };

  system.stateVersion = "26.11";
}
