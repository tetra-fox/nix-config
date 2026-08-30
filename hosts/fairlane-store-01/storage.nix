# /mnt/bigdisk   fairlane's ext4 passthrough disk, split one level down so the two consumers
# don't overlap:
#   /mnt/bigdisk/media                the shared library, served over NFS to svc-01 as its
#                                     fsid=0 root. the inner media/torrents/nzb names are what
#                                     svc-01's arr DBs have baked in, so they stay as they are
#   /mnt/bigdisk/backup/homeassistant gzipped HA backups pushed over NFS by the HAOS box. the
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
  # haosIp is HAOS's internal-VLAN leg (see the site facts), so the export and firewall scope
  # to inter-VM traffic. HAOS must mount this box's internal IP or its NFS source won't match.
  # it connects as root, so the export all_squashes root to admin:users. the backups are HAOS's
  # private blobs, deliberately NOT group media.
  haIp = config.lab.appliances.haosIp;
in {
  users.groups.${config.lab.media.group}.gid = config.lab.media.gid;

  lab.site.dataDirGroup = config.lab.media.group;

  systemd.tmpfiles.rules = [
    # the library container, which is also svc-01's fsid=0 export root. `d` because the three
    # trees below use `Z`, which adjusts an existing path but never creates one, so without
    # this nothing declares who owns the root of that export
    "d /mnt/bigdisk/media 2775 admin media -"
    # setgid so new files inherit group media, so the arr uids on svc-01 keep group write
    # across the nfs export (it keeps numeric uids, so the gid is what lines up).
    "Z /mnt/bigdisk/media/media - admin media 2775"
    "Z /mnt/bigdisk/media/torrents - admin media 2775"
    "Z /mnt/bigdisk/media/nzb - admin media 2775"
    # HA backups, owned admin:users to match the export's all_squash (anonuid=1000
    # anongid=100). `d` not `Z`: create the dirs and set their own mode, never recurse into
    # the tarballs HAOS wrote
    "d /mnt/bigdisk/backup 0755 admin users -"
    "d /mnt/bigdisk/backup/homeassistant 0700 admin users -"
  ];

  # the passthrough media disk. mount by uuid, never /dev/sdX. nofail so a missing disk
  # doesn't wedge boot. ext4 for lower write amplification (content is re-downloadable).
  fileSystems."/mnt/bigdisk" = {
    device = "/dev/disk/by-uuid/dffc8a76-9a1c-411a-9a53-4f3f720bf9f5";
    fsType = "ext4";
    options = ["defaults" "noatime" "nofail" "commit=60"];
  };

  lab.topology.provides = [caps.storage.name];

  # one fsid=0 root per client, the same shape as mesa-store-01: safe because each export is
  # scoped to a single non-overlapping client IP. the two roots are siblings, so neither client
  # can see into the other's tree. svc-01 mounts `:/` and lands on the library, which still
  # holds media/torrents/nzb at the paths its arr DBs expect.
  services.nfs.server = {
    enable = true;
    exports = ''
      /mnt/bigdisk/media ${svcIp}(rw,sync,no_subtree_check,fsid=0)
      /mnt/bigdisk/backup/homeassistant ${haIp}(rw,sync,no_subtree_check,fsid=0,all_squash,anonuid=1000,anongid=100)
    '';
  };

  networking.firewall.extraInputRules = allowFrom [svcIp haIp] [2049];
}
