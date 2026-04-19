{ pkgs, lib, ... }:
let
  material-symbols-filled = import ./material-symbols-filled.nix { inherit pkgs; };
in
{
  programs.quickshell = {
    enable = true;
    package = pkgs.quickshell;
    configs.default = ./shell;
    systemd = {
      enable = true;
      target = "wayland-session@hyprland.desktop.target";
    };
  };

  home.activation.restartQuickshell = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
    ${pkgs.systemd}/bin/systemctl --user restart quickshell.service 2>/dev/null || true
  '';

  home.packages = with pkgs; [
    overskride
    iproute2
    iw
    material-symbols-filled
    networkmanager
    wl-clipboard
  ];
}
