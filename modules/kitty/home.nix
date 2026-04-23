{
  pkgs,
  config,
  lib,
  ...
}: {
  programs.kitty = {
    enable = true;

    enableGitIntegration = true;
    shellIntegration.enableZshIntegration = true;

    font = {
      name = lib.head config.fonts.fontconfig.defaultFonts.monospace;
      size = 12;
    };

    # see https://github.com/kovidgoyal/kitty-themes/tree/master/themes
    themeFile = "Catppuccin-Mocha";
  };
}
