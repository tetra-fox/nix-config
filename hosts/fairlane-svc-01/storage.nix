# /mnt/media                    media + torrents + nzb (passthrough ext4 disk)
# /var/lib/fairlane/<service>   state for every native + container service (one backup target)
#
# the media disk is a cheap DRAM-less QLC SATA SSD (warranty replacement of the first
# one, which locked up under sustained writes). ext4 over btrfs: lower write
# amplification on a write-fragile drive, and the simplest/most-recoverable fs since
# the content is re-downloadable. NCQ is disabled on the host (libata.force=noncq on
# pooltoy). nofail keeps the box booting if the disk wedges/is absent; the failure
# domain is intentionally just the media stack (HA + dns live on plush, not here).
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

  # gate every media-writing service on the mount so none start (and write into the bare
  # mountpoint on the root fs, filling root + shadowing the real content on remount) when
  # the flaky disk is wedged. RequiresMountsFor pulls in the mount unit. (prowlarr is an
  # indexer proxy, doesn't touch the disk, so it's omitted -- same set as mesa-svc-01.)
  systemd.services = builtins.listToAttrs (map (name: {
      inherit name;
      value.unitConfig.RequiresMountsFor = [media];
    }) ["sonarr" "radarr" "jellyfin" "qbittorrent" "sabnzbd"]);

  fileSystems.${media} = {
    device = "/dev/disk/by-uuid/dffc8a76-9a1c-411a-9a53-4f3f720bf9f5";
    fsType = "ext4";
    # nofail: boot even when the flaky disk is wedged/absent
    # noatime: fewer writes to a slow DRAM-less drive
    options = ["defaults" "noatime" "nofail" "commit=60" "x-systemd.device-timeout=15s"];
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
