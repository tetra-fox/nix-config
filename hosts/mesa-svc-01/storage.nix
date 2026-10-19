{config, ...}: {
  lab.storage.mounts = {
    media.mountpoint = "/mnt/store";
    music = {
      mountpoint = "/mnt/music";
      gatedServices = ["jellyfin"];
    };
  };

  # so service uids can co-write
  lab.site.dataDirGroup = config.lab.media.group;
}
