# disko layout for a single-disk proxmox vm using virtio-scsi.
# 512M EFI system partition (FAT32, /boot), rest = ext4 /.
#
# boot drive MUST be at scsi0. use VirtIO SCSI single.
#
# nixos-anywhere consumes this on first install:
#   nix run github:nix-community/nixos-anywhere -- --flake .#<host> root@<ip>
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0";
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
            mountpoint = "/";
          };
        };
      };
    };
  };
}
