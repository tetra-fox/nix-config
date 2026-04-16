{ pkgs, ... }:

let
  clipse = "hyprctl clients -j | jq -e \'.[] | select(.class==\"clipse\")\' >/dev/null && hyprctl dispatch killwindow class:clipse || kitty --class clipse -e clipse";
in
{
  home.packages = [ pkgs.wl-clipboard ];

  services.clipse.enable = true;

  wayland.windowManager.hyprland.settings = {
    bind = [ "SUPER,V,exec,${clipse}" ];

    windowrule = [ "match:class clipse, float on, size 622 652, pin on" ];
  };
}
