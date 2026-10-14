{modules, ...}: {
  imports = [modules.services.media-mount.system];

  lab.storage.mediaMount = {
    enable = true;
    mountpoint = "/mnt/immich";
    gatedServices = ["immich-server"];
  };
}
