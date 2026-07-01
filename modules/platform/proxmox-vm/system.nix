# proxmox/qemu guest config. a VM host never carries a hand-written
# hardware-configuration.nix; this plus modules.platform.disko.proxmox-vm replace it.
{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # without virtio_scsi the initrd can't see the VirtIO SCSI boot disk and boot hangs
  boot.initrd.availableKernelModules = ["uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod"];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
