{lib, ...}: {
  # stylix's cursor module sets home.pointerCursor's fields but not enable
  home.pointerCursor.enable = true;

  # no browser target: stylix has no zen-browser module, zen themes itself
  stylix.targets = {
    # vscode/home.nix reads fonts.fontconfig.defaultFonts
    fontconfig.enable = true;
    hyprpaper.enable = true;

    kitty.enable = true;
    gtk.enable = true;
    qt.enable = true;
    hyprland.enable = true;
    helix.enable = true;
  };

  # qt.enable also writes these into the systemd --user env, which every session of
  # this uid shares. hyprland gets qt5ct through uwsm/env-hyprland (hyprland/home.nix)
  home.sessionVariables = {
    QT_QPA_PLATFORMTHEME = lib.mkForce "kde";
    QT_STYLE_OVERRIDE = lib.mkForce "breeze";
  };
  systemd.user.sessionVariables = {
    QT_QPA_PLATFORMTHEME = lib.mkForce "kde";
    QT_STYLE_OVERRIDE = lib.mkForce "breeze";
  };
}
