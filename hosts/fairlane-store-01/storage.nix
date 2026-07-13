# /mnt/media   the shared library (media + torrents + nzb), served over NFS to svc-01. this is
# fairlane's existing ext4 passthrough disk, now on its own store box instead of the svc monolith.
{
  config,
  lib,
  fleet,
  nixosConfigurations,
  ...
}: let
  siteData = config.lab.site.dataDir;
  # the media host's internal-VLAN IP; the export + firewall scope to it.
  svcIp =
    (import fleet.topology {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }).mediaHostIp;
in {
  users.groups.media.gid = 1002;

  systemd.tmpfiles.rules = [
    "d ${siteData} 0755 root media -"
    # setgid so new files inherit group media, letting service uids + SMB @users share write.
    "Z /mnt/media/media - admin media 2775"
    "Z /mnt/media/torrents - admin media 2775"
    "Z /mnt/media/nzb - admin media 2775"
  ];

  # the passthrough media disk. mount by uuid, never /dev/sdX. nofail so a missing disk
  # doesn't wedge boot. ext4 for lower write amplification (content is re-downloadable).
  fileSystems."/mnt/media" = {
    device = "/dev/disk/by-uuid/dffc8a76-9a1c-411a-9a53-4f3f720bf9f5";
    fsType = "ext4";
    options = ["defaults" "noatime" "nofail" "commit=60"];
  };

  lab.topology.provides = ["storage"];

  # single fsid=0 root scoped to svc-01; it mounts `:/`. keeps numeric uids so arr imports
  # land <svc-uid>:media, not nobody.
  services.nfs.server = {
    enable = true;
    exports = ''
      /mnt/media ${svcIp}(rw,sync,no_subtree_check,fsid=0)
    '';
  };

  networking.firewall.extraInputRules = ''
    ip saddr ${svcIp} tcp dport 2049 accept
  '';

  services.samba.settings = {
    global."server string" = "fairlane";
    store = {
      path = "/mnt/media";
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
