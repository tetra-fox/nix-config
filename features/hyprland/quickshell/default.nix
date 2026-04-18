{ pkgs, ... }:
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
}
