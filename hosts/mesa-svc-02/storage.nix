# /mnt/immich   the photo library, NFS-mounted from store-01 (megamax/immich). immich's postgres
# runs LOCALLY under /var/lib (not over nfs); only the library and immich's db-dump backups live on
# the remote mount. see modules/services/immich.
{modules, ...}: {
  imports = [modules.services.media-mount.system];

  lab.storage.mediaMount = {
    enable = true;
    mountpoint = "/mnt/immich";
    gatedServices = ["immich-server"];
  };
}
