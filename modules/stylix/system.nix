{
  pkgs,
  shared,
  inputs,
  ...
}: {
  # without plasma enabled, nixos doesn't link these by default, so dolphin can't find CatppuccinMocha.colors
  environment.pathsToLink = [
    "/share/color-schemes"
    "/share/plasma"
    "/share/wallpapers"
  ];

  stylix.targets = {
    # apps pick their own colors for now; font targets stay on so fonts are installed AND
    # fonts.fontconfig.defaultFonts is populated (modules like cosmic/kitty/vscode read it via lib.head)
    font-packages.enable = true;
    fontconfig.enable = true;
  };

  stylix = {
    enable = true;
    autoEnable = false;
    polarity = "dark";

    image = shared.wallpapers + "/andrei-castanha-cCWKt_dHMvQ-unsplash-rotate.jpg";
    base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base24/catppuccin-mocha.yaml";
    # catppuccin puts blue at base0D (primary accent) and mauve at base0E; swap for mauve-accented ui
    override = {
      base0D = "cba6f7"; # mauve
      base0E = "89b4fa"; # blue
    };

    fonts = {
      serif = {
        package = inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system}.ny;
        name = "New York";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      monospace = {
        package = pkgs.nerd-fonts.caskaydia-cove;
        name = "CaskaydiaCove Nerd Font";
      };
      emoji = {
        package = pkgs.apple-color-emoji-linux;
        name = "Apple Color Emoji";
      };
    };

    cursor = {
      package = pkgs.rose-pine-hyprcursor;
      name = "rose-pine-hyprcursor";
      size = 26;
    };

    # sizes.terminal * 4/3 = vscode editor font size; 10.5 -> 14pt
    fonts.sizes.terminal = 10.5;
  };
}
