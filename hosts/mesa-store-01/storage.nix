# the storage tier: this box owns the media disk and serves it two ways.
#   NFS  -> the service VMs (svc-01 arrs/downloaders, jelly-01 jellyfin) mount the
#           library; exported without all_squash so the pinned numeric uids pass
#           through and files stay <svc-uid>:media instead of squashing to nobody.
#   SMB  -> real people (@users) and the HA backup user, local-account auth.
#
# /mnt/vol_1/milkfish        media + torrents + nzb (the shared library)
# /mnt/vol_1/homeassistant   HA backups
# siteData (/var/lib/mesa) comes from the `mesa` site tag (modules/sites/mesa.nix)
{siteData, ...}: let
  # the service VMs that mount the library over NFS. svc-01 runs the arrs + qbit/sab
  # (read-write); jelly-01 will mount read-only once it exists (Phase 5).
  svcIp = "192.168.10.208";
in {
  users.groups.media = {
    gid = 1002;
  };

  systemd.tmpfiles.rules = [
    "d ${siteData} 0755 root media -"

    # setgid so everything created under the library inherits group `media`; the
    # service uids (sonarr/radarr/qbit/sab, all in media) and SMB @users share write.
    "Z /mnt/vol_1/milkfish/media - admin media 2775"
    "Z /mnt/vol_1/milkfish/torrents - admin media 2775"
    "Z /mnt/vol_1/milkfish/nzb - admin media 2775"
  ];

  # mount the media disk by filesystem uuid, never by /dev/sdX or a by-id scsi path:
  # there are two same-size disks on this VM and scsi enumeration can swap on reboot,
  # so the uuid is the only stable handle. nofail so a missing disk doesn't wedge boot.
  fileSystems."/mnt/vol_1" = {
    device = "/dev/disk/by-uuid/e9bcf2e9-1a1d-4fd8-b2ab-6852302dcb78";
    fsType = "btrfs";
    options = ["defaults" "noatime" "nofail"];
  };

  # ---- NFS server: serve the library to the service VMs ----
  # NFSv4 only (no rpcbind/statd/mountd port sprawl). no all_squash: the clients run
  # the same pinned uids (Phase 0a), so numeric ownership passes through and an arr
  # import lands <svc-uid>:media rather than nobody:nobody. svc-01 gets rw; jelly-01
  # will be added read-only in Phase 5.
  services.nfs.server = {
    enable = true;
    # a single v4 pseudo-root; the export path sits directly under it
    exports = ''
      /mnt/vol_1/milkfish ${svcIp}(rw,sync,no_subtree_check,fsid=0)
    '';
  };

  # open NFSv4 (2049/tcp) to the service VMs only, not the whole VLAN. source-scoped
  # extraInputRules need the nftables backend, which the base profile enables fleet-wide.
  networking.firewall.extraInputRules = ''
    ip saddr ${svcIp} tcp dport 2049 accept
  '';

  # ---- SMB shares (moved from svc-01): local-account auth, no auth-tier dependency ----
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
