{pkgs, ...}: {
  home.pointerCursor.hyprcursor.enable = true;

  home.packages = [pkgs.hyprcursor];
}
