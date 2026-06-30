{username, ...}: {
  stylix.targets = {
    firefox.profileNames = [username];
    # cosmic/vscode read config.fonts.fontconfig.defaultFonts via lib.head; keep this on so that list stays populated
    fontconfig.enable = true;
    hyprpaper.enable = true;

    kitty.enable = true;
    gtk.enable = true;
    qt.enable = true;
    hyprland.enable = true;
    helix.enable = true;
  };
}
