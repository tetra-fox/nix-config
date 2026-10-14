{
  pkgs,
  lib,
  inputs,
  ...
}: {
  programs.yazi = {
    enable = true;
    # yazi's flake pins its own nixpkgs, which no longer evaluates on x86_64-darwin.
    # darwin falls back to the module default, pkgs.yazi from the 26.05-darwin pin
    package = lib.mkIf pkgs.stdenv.hostPlatform.isLinux inputs.yazi.packages.${pkgs.stdenv.hostPlatform.system}.default;

    plugins =
      {
        inherit
          (pkgs.yaziPlugins)
          mount
          chmod
          clipboard
          compress
          diff
          drag
          duckdb
          dupes
          git
          glow
          mediainfo
          nav-parent-panel
          ouch
          restore
          rich-preview
          starship
          sudo
          ;
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        inherit
          (pkgs.yaziPlugins)
          recycle-bin
          wl-clipboard
          ;
      };
  };
}
