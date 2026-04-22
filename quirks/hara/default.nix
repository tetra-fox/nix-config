{ username, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./extra-drives.nix
    ./ram-led-suspend-hook.nix
    # ./scarlett-volume-lock.nix
    ./windows-systemd-boot-entry.nix
  ];

  home-manager.users.${username}.imports = [
    ./hyprland-display-configuration.nix
  ];
}
