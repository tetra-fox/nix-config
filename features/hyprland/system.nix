{ pkgs, ... }:

{
  programs.hyprland = {
    enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  environment.systemPackages = with pkgs; [
    qt5.qtwayland
    qt6.qtwayland
    libnotify
  ];
}
