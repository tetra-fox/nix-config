{
  pkgs,
  lib,
  ...
}: {
  wayland.windowManager.hyprland.extraLuaFiles."1password".content =
    pkgs.replaceVars ./_1password.lua {
      app2unit = lib.getExe pkgs.app2unit;
      onepassword = lib.getExe' pkgs._1password-gui "1password";
    };
}
