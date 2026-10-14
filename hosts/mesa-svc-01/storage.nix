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

  # so service uids can co-write
  lab.site.dataDirGroup = config.lab.media.group;
}
