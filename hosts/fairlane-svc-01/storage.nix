# /mnt/media                    media + torrents + nzb (passthrough ext4 disk)
# /var/lib/fairlane/<service>   state for every native + container service (one backup target)
#
# the media disk is a DRAM-less QLC SATA SSD prone to wedging under sustained writes.
# ext4 over btrfs for lower write amplification, and the content is re-downloadable so
# recoverability trumps checksums. NCQ is disabled on the host (libata.force=noncq on pooltoy).
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

    # Z fixes ownership on existing paths but won't create them, so a wedged disk makes
    # these no-ops instead of shadowing the real content with empty dirs on the root fs.
    "Z ${media}/media - admin media 2775"
    "Z ${media}/torrents - admin media 2775"
    # nzb is net-new, so d (create); RequiresMountsFor gates sabnzbd on the mount, so this
    # only effectively runs with the disk present.
    "d ${media}/nzb 2775 admin media -"
  ];

  # gate media-writing services on the mount so a wedged disk can't have them write into
  # the bare mountpoint on the root fs. same set as mesa-svc-01 (prowlarr doesn't touch disk).
  systemd.services = builtins.listToAttrs (map (name: {
    inherit name;
    value.unitConfig.RequiresMountsFor = [media];
  }) ["sonarr" "radarr" "jellyfin" "qbittorrent" "sabnzbd"]);

  fileSystems.${media} = {
    device = "/dev/disk/by-uuid/dffc8a76-9a1c-411a-9a53-4f3f720bf9f5";
    fsType = "ext4";
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
