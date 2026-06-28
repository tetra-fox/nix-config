# proxmox guest hardware config. provides the qemu-guest profile + the initrd
# kernel modules (virtio_scsi, sd_mod, ...) needed to find the boot disk on a
# VirtIO SCSI single controller. without this the initrd can't see the disk and
# boot times out waiting for /dev/disk/by-partlabel/disk-main-root.
{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = ["uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
