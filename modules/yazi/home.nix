{
  pkgs,
  inputs,
  ...
}: {
  programs.yazi = {
    enable = true;
    package = inputs.yazi.packages.${pkgs.stdenv.hostPlatform.system}.default;

    plugins = {
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
        recycle-bin
        restore
        rich-preview
        starship
        sudo
        wl-clipboard
        ;
    };
  };
}
