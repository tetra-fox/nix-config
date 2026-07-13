# /mnt/immich   the photo library, NFS-mounted from store-01 (megamax/immich).
# immich's postgres runs LOCALLY under /var/lib (not over nfs); only the library and
# immich's db-dump backups live on the remote mount. see modules/services/immich.
{
  config,
  lib,
  fleet,
  nixosConfigurations,
  ...
}: let
  storeIp =
    (import fleet.topology {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }).storageHostIp;
in {
  # the share is its own fsid=0 v4 root scoped to this host, so mount `:/`. automount +
  # idle-timeout + nofail so a store-01 reboot doesn't wedge boot here.
  fileSystems."/mnt/immich" = {
    device = "${storeIp}:/";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "_netdev"
    ];
  };

  # gate immich on the mount so it doesn't race it and write into the empty mountpoint
  # underneath; RequiresMountsFor pulls the automount up first.
  systemd.services.immich-server.unitConfig.RequiresMountsFor = ["/mnt/immich"];
}
