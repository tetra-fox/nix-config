{username, ...}: {
  # stylix's cursor module sets home.pointerCursor.{name,package,size,...} but
  # not enable; newer home-manager deprecated inferring enable from their presence
  home.pointerCursor.enable = true;

  stylix.targets = {
    firefox.profileNames = [username];
    # keep on so fonts.fontconfig.defaultFonts stays populated (cosmic/vscode read it via lib.head)
    fontconfig.enable = true;
    hyprpaper.enable = true;

    kitty.enable = true;
    gtk.enable = true;
    qt.enable = true;
    hyprland.enable = true;
    helix.enable = true;
  };
}
