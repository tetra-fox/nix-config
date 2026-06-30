{
  pkgs,
  inputs,
  ...
}: let
  alejandra = inputs.alejandra.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  programs.vscodium.profiles.default = {
    extensions = with pkgs.open-vsx; [
      jnoortheen.nix-ide
    ];
    userSettings = {
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "${pkgs.nixd}/bin/nixd";
      # nix.formatterPath is ignored once nixd.formatting.command is set
      "nix.serverSettings" = {
        nixd = {
          formatting.command = ["${alejandra}/bin/alejandra"];
        };
      };
      "[nix]" = {
        "editor.defaultFormatter" = "jnoortheen.nix-ide";
      };
    };
  };
}
