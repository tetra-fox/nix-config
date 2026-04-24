{
  config,
  lib,
  ...
}: {
  programs.kitty = {
    enable = true;

    enableGitIntegration = true;
    shellIntegration.enableZshIntegration = true;

    # stylix's kitty target would set both; with autoEnable = false we own font here
    font = {
      name = lib.head config.fonts.fontconfig.defaultFonts.monospace;
      size = 12;
    };
  };
}
