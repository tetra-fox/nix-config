# mesa storage layout:
#   /mnt/vol_1/milkfish        media + torrents + nzb
#   /mnt/vol_1/homeassistant   HA backups
#   /var/lib/mesa/<service>    state for every native + container service
#                              (single backup target)
{...}: let
  siteData = "/var/lib/mesa";
in {
  # exported so stack files can take `siteData` from module args
  _module.args.siteData = siteData;

  # shared group for service users that need access to the media tree
  users.groups.media = {
    gid = 1002;
  };

  systemd.tmpfiles.rules = [
    "d ${siteData} 0755 root media -"

    "Z /mnt/vol_1/milkfish/media - admin media 2775"
    "Z /mnt/vol_1/milkfish/torrents - admin media 2775"
    "Z /mnt/vol_1/milkfish/nzb - admin media 2775"
  ];

  fileSystems."/mnt/vol_1" = {
    device = "/dev/disk/by-uuid/e9bcf2e9-1a1d-4fd8-b2ab-6852302dcb78";
    fsType = "btrfs";
    options = ["defaults" "noatime" "nofail"];
  };

  # non-admin local account for HAOS
  users.users.hassbackupuser = {
    isSystemUser = true;
    uid = 1069;
    group = "users";
    description = "HAOS backup samba user";
  };

  services.samba.settings = {
    global = {
      "server string" = "mesa";
      "fruit:model" = "MacPro7,1@ECOLOR=226,226,224"; # rack pro icon in Finder :3
    };

    milkfish = {
      path = "/mnt/vol_1/milkfish";
      browseable = "yes";
      "read only" = "no";
      "guest ok" = "yes";
      "valid users" = "@users";
      "write list" = "@users";
      "create mask" = "0664";
      "directory mask" = "0775";
      "force group" = "media";
    };

    homeassistant = {
      path = "/mnt/vol_1/homeassistant";
      browseable = "yes";
      "read only" = "no";
      "guest ok" = "no";
      "valid users" = "@users hassbackupuser";
      "write list" = "@users hassbackupuser";
      "create mask" = "0664";
      "directory mask" = "0775";
    };
  };
}
