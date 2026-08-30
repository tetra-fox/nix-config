# /mnt/media   the shared library, NFS-mounted from fairlane-store-01 (its /mnt/bigdisk/media,
# exported as that client's fsid=0 root). mounted at /mnt/media here, not mesa's /mnt/store,
# because fairlane's arr DBs have root/download dirs baked in under /mnt/media -- changing this
# path would make every item show as missing. this box is a pure NFS client, like mesa-svc-01.
{
  config,
  modules,
  ...
}: {
  imports = [modules.services.media-mount.system];

  lab.storage.mediaMount = {
    enable = true;
    mountpoint = "/mnt/media";
  };

  # dataDir root is group media so service uids can co-write
  lab.site.dataDirGroup = config.lab.media.group;
}
