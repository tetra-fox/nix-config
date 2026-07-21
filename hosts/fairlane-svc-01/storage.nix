# /mnt/media   the shared library, NFS-mounted from fairlane-store-01. mounted at /mnt/media (not
# mesa's /mnt/store) because fairlane's arr DBs have root/download dirs baked in under /mnt/media --
# changing the path would make every item show as missing. this box is a pure NFS client, like
# mesa-svc-01.
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
