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
    # Qt Wayland support — required for Qt apps to render natively on Wayland
    # instead of falling back to XWayland.
    qt5.qtwayland
    qt6.qtwayland

    # notify-send CLI for scripts and keybinds
    libnotify
  ];
}
