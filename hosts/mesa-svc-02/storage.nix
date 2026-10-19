{modules, ...}: {
  imports = [modules.services.store-mount.system];

  lab.storage.mounts.immich = {
    mountpoint = "/mnt/immich";
    gatedServices = ["immich-server"];
  };
}
