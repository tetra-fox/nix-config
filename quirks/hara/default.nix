{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    # ./suspend-hook.nix
    # ./scarlett-volume-lock.nix
    ./windows-boot-entry.nix
  ];
}
