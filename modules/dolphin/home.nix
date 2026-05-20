{pkgs, ...}: let
  # KF6's kservice no longer ships applications.menu; plasma-workspace ships
  # plasma-applications.menu, so prefix-resolve via XDG_MENU_PREFIX.
  dolphin-wrapped = pkgs.symlinkJoin {
    name = "dolphin-wrapped";
    paths = [pkgs.kdePackages.dolphin];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      rm $out/bin/dolphin
      makeWrapper ${pkgs.kdePackages.dolphin}/bin/dolphin $out/bin/dolphin \
        --set XDG_MENU_PREFIX "plasma-" \
        --set XDG_CONFIG_DIRS "${pkgs.kdePackages.plasma-workspace}/etc/xdg:$XDG_CONFIG_DIRS" \
        --run "${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental ${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu"
    '';
  };
in {
  home.packages =
    [dolphin-wrapped]
    ++ (with pkgs.kdePackages; [
      qtsvg
      kio # needed since 25.11
      kio-fuse
      kio-extras
      ark
      audiocd-kio
      baloo # file tagging / search index
      dolphin-plugins # git/hg/dropbox/mount integration
      kio-admin
      kio-gdrive
      kompare # diff
      konsole
      ffmpegthumbs
      kdegraphics-thumbnailers
      kimageformats # GIMP .xcf, .heic
      qtimageformats # .webp, .tiff, .tga, .jp2
    ])
    ++ (with pkgs; [
      icoutils # .ico, .cur, embedded .exe icons
      libappimage # embedded .AppImage icons
      resvg # svg thumbnails
      taglib
    ]);

  # fixes dolphin theming under non-KDE compositors (hyprland, niri)
  xdg.configFile."kdeglobals".text = ''
    [UiSettings]
    ColorScheme=*
  '';
}
