{...}: {
  # hardware-configuration.nix is gone -- the proxmox-VM platform config (qemu-guest +
  # virtio initrd + hostPlatform) now comes from modules.proxmox-vm.system. only the
  # genuine host-specific quirk (the passed-through GTX 1080) remains.
  imports = [
    ./gtx-1080.nix
  ];
}
