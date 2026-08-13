{username, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./acpi-thermal-shutdown-fix.nix
    ./cpu-governor.nix
    ./extra-drives.nix
    ./kernel-tuning.nix
    ./network-tuning.nix
    ./ram-led-suspend-hook.nix
    ./scarlett-volume-lock.nix
    ./windows-systemd-boot-entry.nix
  ];

  home-manager.users.${username}.imports = [
    ./hyprland-display-configuration.nix
  ];
}
