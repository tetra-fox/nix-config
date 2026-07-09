{lib, ...}: {
  catppuccin = {
    # stylix does the theming; keep catppuccin/nix ports off. setting autoEnable
    # explicitly opts out of the upcoming default flip where catppuccin.enable
    # stops gating auto-enrolled ports, and silences the deprecation warning
    autoEnable = false;
    flavor = "mocha";
    accent = "mauve";
  };

  # stylix's fonts template hardcodes workbench.colorTheme = "Stylix"; force catppuccin's
  programs.vscodium.profiles.default.userSettings."workbench.colorTheme" =
    lib.mkForce "Catppuccin Mocha";

  # stop stylix from installing its own base16 theme extension for vscode (fonts still managed)
  stylix.targets.vscode.colors.enable = false;
}
