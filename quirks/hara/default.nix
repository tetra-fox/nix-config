{username, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./acpi-thermal-shutdown-fix.nix
    ./cpu-governor.nix
    ./extra-drives.nix
    ./network-tuning.nix
    ./openldap-flaky-test-fix.nix
    ./openvr-jsoncpp-fix.nix # remove when NixOS/nixpkgs#513244 is merged into nixos-unstable
    ./proton-max-map-count.nix
    ./ram-led-suspend-hook.nix
    ./scarlett-volume-lock.nix
    ./scarlett-configuration.nix
    ./windows-systemd-boot-entry.nix
  ];

  home-manager.users.${username}.imports = [
    ./hyprland-display-configuration.nix
  ];
}
