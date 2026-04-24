{username, ...}: {
  stylix.targets = {
    # harmless while stylix.autoEnable = false; kept so it's wired up if targets are re-enabled
    firefox.profileNames = [username];
    # cosmic/vscode read config.fonts.fontconfig.defaultFonts via lib.head;
    # keep the fontconfig target on so that list stays populated under autoEnable = false
    fontconfig.enable = true;
    # wallpaper management still goes through stylix
    hyprpaper.enable = true;

    kitty.enable = true;
    gtk.enable = true;
    qt.enable = true;
    hyprland.enable = true;
    helix.enable = true;
  };
}
