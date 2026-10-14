{
  config,
  modules,
  ...
}: {
  imports = [modules.services.media-mount.system];

  lab.storage.mediaMount = {
    enable = true;
    # baked into the arr DBs, changing it marks every item missing
    mountpoint = "/mnt/media";
  };

  # so service uids can co-write
  lab.site.dataDirGroup = config.lab.media.group;
}
