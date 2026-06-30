# "this host is a proxmox VM" platform config. importing this declares the host runs
# as a proxmox/qemu guest, so it gets the qemu-guest profile (virtio NIC, balloon, the
# guest-side bits) plus the initrd modules to find a VirtIO SCSI boot disk. a VM host
# never carries a hand-written hardware-configuration.nix -- that's for bare metal (e.g.
# hara) where the hardware genuinely differs and needs detection.
#
# this is identical for every proxmox VM; the only thing that ever varied was the
# kvm-{amd,intel} nested-virt module, which these guests don't use, so it's dropped.
# orthogonal to modules.platform.disko.proxmox-vm (disk layout) -- a VM imports both.
{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # initrd modules to find the boot disk on a VirtIO SCSI single controller. without
  # virtio_scsi the initrd can't see the disk and boot times out waiting for
  # /dev/disk/by-partlabel/disk-main-root.
  boot.initrd.availableKernelModules = ["uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod"];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
