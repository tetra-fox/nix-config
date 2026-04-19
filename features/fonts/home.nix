{ pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  apple = inputs.apple-fonts.packages.${system};
in

{
  home.packages = with pkgs; [
    cascadia-code
    nerd-fonts.caskaydia-cove
    apple.sf-pro
    apple.ny
    apple-color-emoji-linux
    inter
  ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [ "New York" ];
      sansSerif = [
        "Inter"
        "SF Pro"
      ];
      monospace = [ "CaskaydiaCove Nerd Font" ];
      emoji = [ "Apple Color Emoji" ];
    };
  };
}
