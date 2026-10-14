# the store host exports the media library as its fsid=0 v4 root, hence `:/`
{
  config,
  lib,
  topo,
  ...
}: let
  cfg = config.lab.storage.mediaMount;
in {
  options.lab.storage.mediaMount = {
    enable = lib.mkEnableOption "the NFS media-library mount from the site store host";

    mountpoint = lib.mkOption {
      type = lib.types.str;
      description = "local mount path for the media library";
      example = "/mnt/store";
    };

    gatedServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "sonarr"
        "radarr"
        "jellyfin"
        "qbittorrent"
        "sabnzbd"
      ];
      description = "services to gate on the mount via RequiresMountsFor, so they don't race the automount and operate on the empty mountpoint underneath";
    };
  };

  config = lib.mkIf cfg.enable {
    # a store reboot must not wedge boot here
    fileSystems.${cfg.mountpoint} = {
      device = "${topo.storageHostIp}:/";
      fsType = "nfs";
      options = [
        "nfsvers=4.2"
        "nofail"
        "x-systemd.automount"
        "x-systemd.idle-timeout=600"
        "_netdev"
      ];
    };

    systemd.services =
      lib.genAttrs cfg.gatedServices
      (_: {unitConfig.RequiresMountsFor = [cfg.mountpoint];});
  };
}
