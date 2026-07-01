# /mnt/vol_1/store           media + torrents + nzb (the shared library)
# /mnt/vol_1/homeassistant   HA backups (NFS only)
{
  config,
  lib,
  modules,
  siteData,
  nixosConfigurations,
  ...
}: let
  # the media host's internal-VLAN IP; the export + firewall scope to it.
  svcIp =
    (import modules.meta.lib.site-topology {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }).mediaHostIp;
  # the HAOS box is an external appliance not on the internal VLAN, so it stays on the
  # server VLAN; it connects as root, so its export all_squashes to the homeassistant user.
  haIp = "192.168.10.5";
in {
  users.groups.media = {
    gid = 1002;
  };

  systemd.tmpfiles.rules = [
    "d ${siteData} 0755 root media -"

    # setgid so new files inherit group media, letting the service uids and SMB @users share write.
    "Z /mnt/vol_1/store/media - admin media 2775"
    "Z /mnt/vol_1/store/torrents - admin media 2775"
    "Z /mnt/vol_1/store/nzb - admin media 2775"
  ];

  # mount by uuid, never /dev/sdX or by-id: two same-size disks here, scsi enumeration
  # can swap on reboot, so the uuid is the only stable handle. nofail so a missing disk
  # doesn't wedge boot.
  fileSystems."/mnt/vol_1" = {
    device = "/dev/disk/by-uuid/e9bcf2e9-1a1d-4fd8-b2ab-6852302dcb78";
    fsType = "btrfs";
    options = ["defaults" "noatime" "nofail"];
  };

  # two fsid=0 roots to different client IPs: the kernel keys the v4 pseudo-root per-client,
  # so each is an isolated namespace and neither client can traverse to the other. each
  # mounts `:/`. store keeps numeric uids (arr imports stay <svc-uid>:media); homeassistant
  # all_squashes to uid 1069 since HAOS connects as root.
  services.nfs.server = {
    enable = true;
    exports = ''
      /mnt/vol_1/store ${svcIp}(rw,sync,no_subtree_check,fsid=0)
      /mnt/vol_1/homeassistant ${haIp}(rw,sync,no_subtree_check,fsid=0,all_squash,anonuid=1069,anongid=100)
    '';
  };

  # source-scoped rules need the nftables backend (base profile enables it fleet-wide).
  networking.firewall.extraInputRules = ''
    ip saddr ${svcIp} tcp dport 2049 accept
    ip saddr ${haIp} tcp dport 2049 accept
  '';

  users.users.homeassistant = {
    isSystemUser = true;
    uid = 1069;
    group = "users";
    description = "home assistant backup owner (NFS squash target)";
  };

  services.samba.settings = {
    global = {
      "server string" = "mesa";
      "fruit:model" = "MacPro7,1@ECOLOR=226,226,224"; # rack pro icon in Finder :3
    };

    store = {
      path = "/mnt/vol_1/store";
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
