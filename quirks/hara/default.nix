{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./ram-led-suspend-hook.nix
    # ./scarlett-volume-lock.nix
    ./windows-systemd-boot-entry.nix
  ];
}
