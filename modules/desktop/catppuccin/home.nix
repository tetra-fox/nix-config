{lib, ...}: {
  catppuccin = {
    # stylix does the theming
    autoEnable = false;
    flavor = "mocha";
    accent = "mauve";
  };

  # stylix's fonts template hardcodes workbench.colorTheme = "Stylix"; force catppuccin's
  programs.vscodium.profiles.default.userSettings."workbench.colorTheme" =
    lib.mkForce "Catppuccin Mocha";

  # fonts stay managed by stylix
  stylix.targets.vscode.colors.enable = false;
}
