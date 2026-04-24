{lib, ...}: {
  catppuccin = {
    flavor = "mocha";
    accent = "mauve";

    # only vscode; stylix owns everything else
    vscode.profiles.default.enable = true;
  };

  # stylix's fonts template hardcodes workbench.colorTheme = "Stylix"; force catppuccin's
  programs.vscode.profiles.default.userSettings."workbench.colorTheme" =
    lib.mkForce "Catppuccin Mocha";

  # stop stylix from installing its own base16 theme extension for vscode (fonts still managed)
  stylix.targets.vscode.colors.enable = false;
}
