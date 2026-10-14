{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  # not pkgs._1password-gui: the nixos module's package bakes in polkitPolicyOwners,
  # which browser integration needs
  onepassword = lib.getExe' osConfig.programs._1password-gui.package "1password";
in {
  imports = [../_autostart.nix];

  wayland.windowManager.hyprland.extraLuaFiles."1password".content = pkgs.replaceVars ./_1password.lua {
    inherit onepassword;
  };

  my.autostart.apps.onepassword = {
    exec = "${onepassword} --silent";
    tray = true;
  };
}
