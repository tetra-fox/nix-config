# /mnt/vol_1/<pool>          media + torrents + nzb
# /var/lib/fairlane/<service>  state for every native + container service (one backup target)
{...}: let
  siteData = "/var/lib/fairlane";
in {
  _module.args.siteData = siteData;

  users.groups.media = {
    gid = 1002;
  };

  systemd.tmpfiles.rules = [
    "d ${siteData} 0755 root media -"

    # TODO: replace <pool> with fairlane's media pool dir, keep paths in sync with lab.arrStack in default.nix
    "Z /mnt/vol_1/TODO/media - admin media 2775"
    "Z /mnt/vol_1/TODO/torrents - admin media 2775"
    "Z /mnt/vol_1/TODO/nzb - admin media 2775"
  ];

  fileSystems."/mnt/vol_1" = {
    # TODO: fairlane's media disk uuid (blkid /dev/disk/by-id/... on the host)
    device = "/dev/disk/by-uuid/TODO";
    fsType = "btrfs";
    options = ["defaults" "noatime" "nofail"];
  };

  services.samba.settings = {
    global = {
      "server string" = "fairlane";
      "fruit:model" = "MacPro7,1@ECOLOR=226,226,224"; # rack pro icon in Finder :3
    };

    # TODO: rename share + path to fairlane's pool
    media = {
      path = "/mnt/vol_1/TODO";
      browseable = "yes";
      "read only" = "no";
      "guest ok" = "yes";
      "valid users" = "@users";
      "write list" = "@users";
      "create mask" = "0664";
      "directory mask" = "0775";
      "force group" = "media";
    };
  };
}
