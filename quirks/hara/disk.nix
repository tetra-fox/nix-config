# one btrfs partition, split into subvolumes so /home can be snapshotted without the store
{inputs, ...}: let
  mountOptions = [
    # level 1 costs less cpu per write than the default 3, for a slightly lower ratio
    "compress=zstd:1"
    "noatime"
    # the rest are what the kernel picks for an nvme drive anyway, spelled out
    "ssd"
    "discard=async"
    "space_cache=v2"
  ];
in {
  imports = [inputs.disko.nixosModules.disko];

  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_2TB_S7YCNJ0L918683L";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
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
            type = "btrfs";
            extraArgs = [
              # mkfs.btrfs refuses a partition that still carries another filesystem's signature
              "--force"
              # the single-disk defaults, spelled out
              "--metadata=dup"
              "--data=single"
            ];
            subvolumes = {
              "@" = {
                mountpoint = "/";
                inherit mountOptions;
              };
              "@nix" = {
                mountpoint = "/nix";
                inherit mountOptions;
              };
              "@home" = {
                mountpoint = "/home";
                inherit mountOptions;
              };
            };
          };
        };
      };
    };
  };

  # a scrub covers the whole filesystem, whichever subvolume it is started on
  services.btrfs.autoScrub.fileSystems = ["/"];
}
