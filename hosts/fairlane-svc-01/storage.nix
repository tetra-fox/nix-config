{config, ...}: {
  # baked into the arr DBs, changing it marks every item missing
  lab.storage.mounts.media.mountpoint = "/mnt/media";

  # so service uids can co-write
  lab.site.dataDirGroup = config.lab.media.group;
}
