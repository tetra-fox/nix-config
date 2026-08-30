# /mnt/media   the shared library (media + torrents + nzb), served over NFS to svc-01. this is
# fairlane's existing ext4 passthrough disk, now on its own store box instead of the svc monolith.
#   /mnt/media/backup/homeassistant   gzipped HA backups pushed over NFS by the HAOS box. the
#                                     only tree here that isn't re-acquirable, and fairlane runs
#                                     no restic, so this is a local copy only (see SCHEDULE.md)
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
  # fairlane's HAOS has no internal-VLAN leg (see the site facts), so unlike mesa it reaches
  # this box over the server VLAN and must mount this host's lab.site.hostIp, not its internal
  # address. it connects as root, so the export all_squashes root to admin:users. the backups
  # are HAOS's private blobs, deliberately NOT group media.
  haIp = config.lab.appliances.haosIp;
in {
  users.groups.${config.lab.media.group}.gid = config.lab.media.gid;

  lab.site.dataDirGroup = config.lab.media.group;

  systemd.tmpfiles.rules = [
    # setgid so new files inherit group media, so the arr uids on svc-01 keep group write
    # across the nfs export (it keeps numeric uids, so the gid is what lines up).
    "Z /mnt/media/media - admin media 2775"
    "Z /mnt/media/torrents - admin media 2775"
    "Z /mnt/media/nzb - admin media 2775"
    # HA backups, owned admin:users to match the export's all_squash (anonuid=1000
    # anongid=100). `d` not `Z`: create the dirs and set their own mode, never recurse into
    # the tarballs HAOS wrote
    "d /mnt/media/backup 0755 admin users -"
    "d /mnt/media/backup/homeassistant 0700 admin users -"
  ];

  # the passthrough media disk. mount by uuid, never /dev/sdX. nofail so a missing disk
  # doesn't wedge boot. ext4 for lower write amplification (content is re-downloadable).
  fileSystems."/mnt/media" = {
    device = "/dev/disk/by-uuid/dffc8a76-9a1c-411a-9a53-4f3f720bf9f5";
    fsType = "ext4";
    options = ["defaults" "noatime" "nofail" "commit=60"];
  };

  lab.topology.provides = [caps.storage.name];

  # one fsid=0 root per client, the same shape as mesa-store-01: safe because each export is
  # scoped to a single non-overlapping client IP. svc-01 mounts `:/` and gets the disk root,
  # so unlike mesa its root also contains the backup tree; 0700 admin:users is what keeps the
  # arr service uids out of it, since narrowing svc-01's export would change the path every
  # arr already has configured.
  services.nfs.server = {
    enable = true;
    exports = ''
      /mnt/media ${svcIp}(rw,sync,no_subtree_check,fsid=0)
      /mnt/media/backup/homeassistant ${haIp}(rw,sync,no_subtree_check,fsid=0,all_squash,anonuid=1000,anongid=100)
    '';
  };

  networking.firewall.extraInputRules = allowFrom [svcIp haIp] [2049];
}
