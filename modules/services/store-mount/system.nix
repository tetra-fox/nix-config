# NFS mounts of the site store host's shares. the store exports its pool root as the v4 root,
# so a share is mounted by name, `store:/media`
{
  config,
  lib,
  topo,
  ...
}: {
  options.lab.storage.mounts = lib.mkOption {
    default = {};
    description = "store shares to mount, keyed by share name (e.g. media, backup/postgres)";
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        mountpoint = lib.mkOption {
          type = lib.types.str;
          description = "local mount path";
          example = "/mnt/store";
        };
        gatedServices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "services to gate on the mount via RequiresMountsFor, so they don't race the automount and operate on the empty mountpoint underneath";
        };
      };
    });
  };

  config = {
    # a store reboot must not wedge boot here
    fileSystems = lib.mapAttrs' (share: m:
      lib.nameValuePair m.mountpoint {
        device = "${topo.storageHostIp}:/${share}";
        fsType = "nfs";
        options = [
          "nfsvers=4.2"
          "nofail"
          "x-systemd.automount"
          "x-systemd.idle-timeout=600"
          "_netdev"
        ];
      })
    config.lab.storage.mounts;

    systemd.services = lib.mkMerge (lib.mapAttrsToList (_: m:
      lib.genAttrs m.gatedServices
      (_: {unitConfig.RequiresMountsFor = [m.mountpoint];}))
    config.lab.storage.mounts);
  };
}
