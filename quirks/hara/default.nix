{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    # ./suspend-hook.nix
    # ./scarlett-volume-lock.nix
    ./windows-systemd-boot-entry.nix
  ];
}
