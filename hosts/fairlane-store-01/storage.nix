# /mnt/media   the shared library (media + torrents + nzb), served over NFS to svc-01. this is
# fairlane's existing ext4 passthrough disk, now on its own store box instead of the svc monolith.
{
  config,
  lib,
  fleet,
  topo,
  caps,
  ...
}: let
  allowFrom = import fleet.nft {inherit lib;};
  # the media host's internal-VLAN IP; the export + firewall scope to it.
  svcIp = topo.mediaHostIp;
in {
  users.groups.${config.lab.media.group}.gid = config.lab.media.gid;

  lab.site.dataDirGroup = config.lab.media.group;

  systemd.tmpfiles.rules = [
    # setgid so new files inherit group media, so the arr uids on svc-01 keep group write
    # across the nfs export (it keeps numeric uids, so the gid is what lines up).
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

  lab.topology.provides = [caps.storage.name];

  # single fsid=0 root scoped to svc-01; it mounts `:/`. keeps numeric uids so arr imports
  # land <svc-uid>:media, not nobody.
  services.nfs.server = {
    enable = true;
    exports = ''
      /mnt/media ${svcIp}(rw,sync,no_subtree_check,fsid=0)
    '';
  };

  networking.firewall.extraInputRules = allowFrom [svcIp] [2049];
}
