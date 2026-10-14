{
  pkgs,
  lib,
  ...
}: {
  imports = [../_autostart.nix];

  my.autostart.targets = ["plasma-workspace.target"];

  # any kde app (dolphin under hyprland too) dbus-activates kded6, whose gtkconfig
  # module overwrites stylix's gtk files and dconf keys with breeze light colors.
  # gtkconfig can't be excluded, it's not an optional plasma6 package.
  # kwriteconfig6 sets one key, kded6rc also holds plasma-written state
  home.activation.disableKdeGtkConfigSync = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kded6rc --group Module-gtkconfig --key autoload --type bool false
  '';
}
