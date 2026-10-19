# /mnt/bigdisk/media                svc-01's media share. inner media/torrents/nzb names are baked
#                                   into svc-01's arr DBs
# /mnt/bigdisk/backup/homeassistant HA backups pushed over NFS by HAOS
{
  config,
  fleet,
  topo,
  caps,
  ...
}: let
  svcIp = topo.mediaHostIp;
  # HAOS's internal-VLAN leg, so HAOS must mount this box's internal IP
  haIp = config.lab.appliances.haosIp;

  nfs = fleet.nfs-exports "/mnt/bigdisk" {
    media = {
      ips = [svcIp];
      options = "rw,sync,no_subtree_check";
    };
    # HAOS connects as root
    "backup/homeassistant" = {
      ips = [haIp];
      options = "rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=100";
    };
  };
in {
  users.groups.${config.lab.media.group}.gid = config.lab.media.gid;

  lab.site.dataDirGroup = config.lab.media.group;

  systemd.tmpfiles.rules = [
    # `Z` never creates a path, so the export root needs its own `d`
    "d /mnt/bigdisk/media 2775 admin media -"
    # setgid so svc-01's arr uids keep group write over nfs
    "Z /mnt/bigdisk/media/media - admin media 2775"
    "Z /mnt/bigdisk/media/torrents - admin media 2775"
    "Z /mnt/bigdisk/media/nzb - admin media 2775"
    # admin:users matches the all_squash anonuid/anongid. `d` so HAOS's tarballs aren't touched
    "d /mnt/bigdisk/backup 0755 admin users -"
    "d /mnt/bigdisk/backup/homeassistant 0700 admin users -"
  ];

  fileSystems."/mnt/bigdisk" = {
    device = "/dev/disk/by-uuid/dffc8a76-9a1c-411a-9a53-4f3f720bf9f5";
    fsType = "ext4";
    options = ["defaults" "noatime" "nofail" "commit=60"];
  };

  lab.topology.provides = [caps.storage.name];

  services.nfs.server = {
    enable = true;
    inherit (nfs) exports;
  };

  networking.firewall.extraInputRules = fleet.allow-from nfs.ips [2049];
}
