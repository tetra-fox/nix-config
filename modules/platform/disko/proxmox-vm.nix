# boot drive must be at scsi0 (use "VirtIO SCSI single" controller in pve)
# nixos-anywhere consumes this on first install:
#   nix run github:nix-community/nixos-anywhere -- --flake .#<host> root@<ip>
#
# one ext4 partition holds everything. it is / on a classic host. with
# environment.persistence.main on it mounts at the persistent path, / is a tmpfs and /nix is
# bound out of the partition, so both shapes keep the same files at the same place on disk
{
  config,
  inputs,
  lib,
  pkgs,
  utils,
  ...
}: let
  persist = config.environment.persistence.main;
  dataMount =
    if persist.enable
    then persist.persistentStoragePath
    else "/";
  disk = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0";
in {
  imports = [inputs.disko.nixosModules.disko];

  # the data partition is the last one, so a disk grown in pve is picked up on the next boot
  boot.growPartition = !persist.enable;

  fileSystems = lib.mkMerge [
    {${dataMount}.autoResize = true;}
    (lib.mkIf persist.enable {
      # impermanence asserts this on every filesystem it binds from or into
      "/".neededForBoot = true;
      ${dataMount}.neededForBoot = true;
    })
  ];

  # boot.growPartition reads the partition off fileSystems."/".device, which is the tmpfs
  systemd.services.growpart-data = lib.mkIf persist.enable (let
    mount = utils.escapeSystemdPath dataMount;
  in {
    wantedBy = ["${mount}.mount"];
    after = ["${mount}.mount"];
    before = ["systemd-growfs@${mount}.service" "shutdown.target"];
    conflicts = ["shutdown.target"];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # growpart returns 1 if the partition is already grown
      SuccessExitStatus = "0 1";
    };
    # 2: disko creates the ESP first
    script = ''
      ${pkgs.cloud-utils.guest}/bin/growpart "$(readlink -f ${disk})" 2
    '';
  });

  disko.devices = {
    disk.main = {
      type = "disk";
      device = disk;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["umask=0077"];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = dataMount;
            };
          };
        };
      };
    };

    nodev = lib.mkIf persist.enable {
      "/" = {
        fsType = "tmpfs";
        mountOptions = ["mode=755"];
      };
      "/nix" = {
        fsType = "none";
        device = "${dataMount}/nix";
        mountOptions = ["bind"];
        # a freshly formatted partition has no nix directory to bind
        preMountHook = "mkdir -p ${config.disko.rootMountPoint}${dataMount}/nix";
      };
    };
  };
}
