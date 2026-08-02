{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  onepassword = lib.getExe' osConfig.programs._1password-gui.package "1password";
in {
  imports = [../_autostart.nix];

  # must be osConfig.programs._1password-gui.package, not pkgs._1password-gui: the
  # nixos module overrides it with polkitPolicyOwners baked in (see
  # modules/desktop/onepassword/system.nix), which is what makes browser integration work
  wayland.windowManager.hyprland.extraLuaFiles."1password".content = pkgs.replaceVars ./_1password.lua {
    inherit onepassword;
  };

  my.autostart.apps.onepassword = {
    exec = "${onepassword} --silent";
    tray = true;
  };
}
