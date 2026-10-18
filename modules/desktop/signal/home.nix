{
  lib,
  pkgs,
  ...
}: {
  imports = [../_autostart.nix];

  home.packages = [pkgs.signal-desktop];

  my.autostart.apps.signal = {
    exec = "${lib.getExe pkgs.signal-desktop} --start-in-tray";
    tray = true;
  };
}
