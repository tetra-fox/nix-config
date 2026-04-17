{ pkgs, ... }:
{
  programs.quickshell = {
    enable = true;
    package = pkgs.quickshell;
    configs.default = ./qml;
    systemd = {
      enable = true;
      target = "hyprland-session.target";
    };
  };
}
