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

  networking.hostName = "mesa-store-01";

  lab = {
    avahi.publish = true;

    sops.secretsFile = ../../secrets/mesa-store-01.yaml;

    site.hostIp = "192.168.10.100";
    site.internalIp = "10.10.0.100";

    backup.restic = {
      enable = true;
      bucket = "mesa-512e3904";
      datasets = [
        {
          name = "megamax/store";
          mountpoint = "/mnt/megamax/store";
        }
        {
          name = "megamax/homeassistant";
          mountpoint = "/mnt/megamax/homeassistant";
        }
        {
          name = "megamax/timemachine";
          mountpoint = "/mnt/megamax/timemachine";
        }
      ];
    };
  };

  system.stateVersion = "26.11";
}
