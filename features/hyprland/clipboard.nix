{
  pkgs,
  main_mod,
  ...
}: let
  clipse = "hyprctl clients -j | jq -e \'.[] | select(.class==\"clipse\")\' >/dev/null && hyprctl dispatch killwindow class:clipse || kitty --class clipse -e clipse";
in {
  home.packages = [pkgs.wl-clipboard];

  services = {
    clipse.enable = true;
    wl-clip-persist = {
      enable = true;
      systemdTargets = "wayland-session@hyprland.desktop.target";
    };
  };

  wayland.windowManager.hyprland.settings = {
    bind = ["${main_mod},V,exec,${clipse}"];

    windowrule = ["match:class clipse, float on, size 622 652, pin on"];
  };
}
