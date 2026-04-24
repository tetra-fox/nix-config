{
  pkgs,
  inputs,
  ...
}: let
  apple = inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system};
in {
  # extras only — default serif/sans/mono/emoji are installed by stylix
  home.packages = [
    pkgs.cascadia-code
    apple.sf-pro
  ];
}
