# /mnt/store                 the shared library, NFS-mounted from store-01 (see the media-mount module)
# /var/lib/mesa/<service>    local state for every native + container service
{
  config,
  modules,
  ...
}: {
  imports = [modules.services.media-mount.system];

  lab.storage.mediaMount = {
    enable = true;
    mountpoint = "/mnt/store";
  };

  # dataDir root is group media so service uids can co-write; the per-service subdirs
  # under it are created by their own modules (arr-stack etc)
  lab.site.dataDirGroup = config.lab.media.group;
}
