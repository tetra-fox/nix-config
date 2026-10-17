{
  pkgs,
  lib,
  ...
}: let
  scale = 1.6;
in {
  wayland.windowManager.hyprland.extraLuaFiles.displays.content = pkgs.replaceVars ./hyprland-displays.lua {
    scale = builtins.toJSON scale;
    # force_zero_scaling leaves xwayland clients to scale themselves, steam and xft
    # apps read the factor from Xft.dpi
    xresources = pkgs.writeText "hyprland-xresources" ''
      Xft.dpi: ${toString (builtins.floor (scale * 96 + 0.5))}
    '';
    xrdb = lib.getExe pkgs.xrdb;
  };
}
