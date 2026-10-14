# replaces hardware-configuration.nix, with modules.platform.disko.proxmox-vm
{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # virtio_scsi: the initrd can't see the boot disk without it
  boot.initrd.availableKernelModules = ["uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod"];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
