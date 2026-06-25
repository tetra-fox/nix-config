# /mnt/media                    media + torrents + nzb (passthrough btrfs disk)
# /var/lib/fairlane/<service>   state for every native + container service (one backup target)
#
# the media disk is a cheap DRAM-less SATA SSD on a flaky controller. NCQ is disabled
# on the proxmox host (libata.force=noncq on pooltoy) because the controller hangs
# juggling queued commands. it can still wedge and require a power-drain of pooltoy;
# nofail keeps the box booting without it, and the failure domain is intentionally
# just the media stack (HA + dns live on plush, not here).
{...}: let
  siteData = "/var/lib/fairlane";
  media = "/mnt/media";
in {
  _module.args.siteData = siteData;

  users.groups.media = {
    gid = 1002;
  };

  systemd.tmpfiles.rules = [
    "d ${siteData} 0755 root media -"

    # Z (not d) recursively fixes ownership on EXISTING paths but won't create them.
    # so if the flaky disk is wedged/unmounted, these are no-ops instead of
    # materializing empty dirs on the root fs that shadow the real ones on remount.
    # the disk already has media/ and torrents/ (recovered layout).
    "Z ${media}/media - admin media 2775"
    "Z ${media}/torrents - admin media 2775"
    # nzb is net-new for sabnzbd. create-if-missing only matters once the disk is
    # mounted; sabnzbd's complete_dir points here. RequiresMountsFor on the unit (below)
    # gates sabnzbd on the mount, so this only effectively runs with the disk present.
    "d ${media}/nzb 2775 admin media -"
  ];

  # gate sabnzbd on the media mount so it doesn't start (and write complete_dir to the
  # root fs) when the disk is wedged. RequiresMountsFor pulls in the mount unit.
  systemd.services.sabnzbd.unitConfig.RequiresMountsFor = [media];

  fileSystems.${media} = {
    device = "/dev/disk/by-uuid/b6f680f5-f842-4dc6-bfd2-eabd5e5819f1";
    fsType = "btrfs";
    # nofail: boot even when the flaky disk is wedged/absent
    # noatime: fewer writes to a slow DRAM-less drive
    options = ["defaults" "noatime" "nofail" "x-systemd.device-timeout=15s"];
  };

  services.samba.settings = {
    global = {
      "server string" = "fairlane";
      "fruit:model" = "MacPro7,1@ECOLOR=226,226,224"; # rack pro icon in Finder :3
    };

    media = {
      path = media;
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
