{
  pkgs,
  lib,
  ...
}: {
  imports = [../_autostart.nix];

  my.autostart.targets = ["plasma-workspace.target"];

  # kded6's gtkconfig module is a required plasma6 package (not excludable via
  # environment.plasma6.excludePackages, which only filters optionalPackages),
  # and kded6 gets D-Bus-activated on demand by any KDE app -- including dolphin
  # under hyprland -- not just inside a plasma session. once loaded it autoloads
  # gtkconfig, which syncs kdeglobals' (BreezeLight) colors into
  # ~/.config/gtk-{3,4}.0/{settings.ini,gtk.css} and dconf's
  # org/gnome/desktop/interface keys, clobbering stylix's dark gtk target
  # regardless of which session is active. that's what was flipping zen/1password
  # to light mode, and what made home-manager activation start refusing to
  # re-backup gtk.css (a stale .bak from a previous clobber was already there).
  # kwriteconfig6 merges just this key instead of taking ownership of the whole
  # file the way xdg.configFile would, since kded6rc also holds unrelated
  # plasma-written state (e.g. PlasmaBrowserIntegration's shownCount).
  home.activation.disableKdeGtkConfigSync = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kded6rc --group Module-gtkconfig --key autoload --type bool false
  '';
}
