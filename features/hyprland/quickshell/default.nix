{ pkgs, lib, ... }:
{
  programs.quickshell = {
    enable = true;
    package = pkgs.quickshell;
    configs.default = ./qml;
    systemd = {
      enable = true;
      target = "wayland-session@hyprland.desktop.target";
    };
  };

  home.packages = with pkgs; [
    blueman
    iproute2
    iw
    material-symbols
    networkmanager
    wl-clipboard
  ];
}
