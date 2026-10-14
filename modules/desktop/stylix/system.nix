{
  pkgs,
  shared,
  inputs,
  ...
}: {
  # without plasma enabled, nixos skips these and dolphin can't find CatppuccinMocha.colors
  environment.pathsToLink = [
    "/share/color-schemes"
    "/share/plasma"
    "/share/wallpapers"
  ];

  stylix.targets = {
    font-packages.enable = true;
    fontconfig.enable = true;
  };

  stylix = {
    enable = true;
    autoEnable = false;
    polarity = "dark";

    image = shared.wallpapers + "/sleepytime.jpg";
    base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base24/catppuccin-mocha.yaml";
    # swap blue and mauve so the primary accent is mauve
    override = {
      base0D = "cba6f7";
      base0E = "89b4fa";
    };

    fonts = {
      serif = {
        package = inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system}.ny;
        name = "New York Small";
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
        package = pkgs.apple-color-emoji;
        name = "Apple Color Emoji";
      };
    };

    cursor = {
      package = pkgs.pony-hyprcursors;
      name = "Rainbow-Dash";
      size = 38;
    };

    fonts.sizes.terminal = 10.5;
  };
}
