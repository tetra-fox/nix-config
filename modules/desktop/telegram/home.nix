{
  lib,
  pkgs,
  ...
}: {
  imports = [../_autostart.nix];

  home.packages = [pkgs.telegram-desktop];

  my.autostart.apps.telegram = {
    exec = "${lib.getExe' pkgs.telegram-desktop "Telegram"} -startintray";
    tray = true;
  };
}
