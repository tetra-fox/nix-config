{
  pkgs,
  config,
  lib,
  ...
}:

{
  programs.kitty = {
    enable = true;

    enableGitIntegration = true;
    shellIntegration.enableZshIntegration = true;

    # See https://sw.kovidgoyal.net/kitty/faq/#things-behave-differently-when-running-kitty-from-system-launcher-vs-from-another-terminal
    environment = {
      "read_from_shell" = "PATH LANG LC_* XDG_* EDITOR VISUAL";
    };

    font = {
      name = lib.head config.fonts.fontconfig.defaultFonts.monospace;
      size = 12;
    };

    # see https://github.com/kovidgoyal/kitty-themes/tree/master/themes
    themeFile = "Catppuccin-Mocha";
  };
}
