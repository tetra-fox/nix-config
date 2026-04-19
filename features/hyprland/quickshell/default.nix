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

  home.activation.restartQuickshell = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
    ${pkgs.systemd}/bin/systemctl --user restart quickshell.service 2>/dev/null || true
  '';

  home.packages = with pkgs; [
    blueman
    iproute2
    iw
    material-symbols
    networkmanager
    wl-clipboard
  ];
}
