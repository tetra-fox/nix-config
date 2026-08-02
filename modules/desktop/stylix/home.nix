{
  username,
  lib,
  ...
}: {
  # stylix's cursor module sets home.pointerCursor.{name,package,size,...} but
  # not enable; newer home-manager deprecated inferring enable from their presence
  home.pointerCursor.enable = true;

  stylix.targets = {
    firefox.profileNames = [username];
    # keep on so fonts.fontconfig.defaultFonts stays populated (vscode reads it via lib.head)
    fontconfig.enable = true;
    hyprpaper.enable = true;

    kitty.enable = true;
    gtk.enable = true;
    qt.enable = true;
    hyprland.enable = true;
    helix.enable = true;
  };

  # qt.enable writes QT_QPA_PLATFORMTHEME/QT_STYLE_OVERRIDE into both the shell
  # env and the systemd --user manager's env, and the latter is shared across
  # every session for this user (there's one systemd --user instance per UID,
  # not per login), so left alone it leaks stylix's qt5ct/kvantum choice into
  # the plasma session and fights systemsettings over qt theming. pin the
  # shared/global value back to plasma's own kde+breeze; hyprland gets qt5ct
  # session-scoped instead, via ~/.config/uwsm/env-hyprland (hyprland/home.nix)
  home.sessionVariables = {
    QT_QPA_PLATFORMTHEME = lib.mkForce "kde";
    QT_STYLE_OVERRIDE = lib.mkForce "breeze";
  };
  systemd.user.sessionVariables = {
    QT_QPA_PLATFORMTHEME = lib.mkForce "kde";
    QT_STYLE_OVERRIDE = lib.mkForce "breeze";
  };
}
