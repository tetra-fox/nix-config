{username, ...}: {
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
