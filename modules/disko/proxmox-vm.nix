# disko layout for a proxmox VM boot drive. the "being a proxmox VM" platform config
# (qemu-guest profile, virtio initrd modules) lives in modules.proxmox-vm.system --
# this module is only about the disk.
#
# boot drive must be at scsi0 (use "VirtIO SCSI single" controller in pve)
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
