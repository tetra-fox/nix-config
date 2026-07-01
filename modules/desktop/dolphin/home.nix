{pkgs, ...}: {
  home.packages =
    [pkgs.kdePackages.dolphin]
    ++ (with pkgs.kdePackages; [
      qtsvg
      kio
      kio-fuse
      kio-extras
      ark
      audiocd-kio
      baloo
      dolphin-plugins # git/hg/dropbox/mount integration
      kio-admin
      kio-gdrive
      kompare
      konsole
      ffmpegthumbs
      kdegraphics-thumbnailers
      kimageformats # GIMP .xcf, .heic
      qtimageformats # .webp, .tiff, .tga, .jp2
    ])
    ++ (with pkgs; [
      icoutils # .ico, .cur, embedded .exe icons
      libappimage # embedded .AppImage icons
      resvg
      taglib
    ]);

  # fixes dolphin theming under non-KDE compositors (hyprland, niri)
  xdg.configFile."kdeglobals".text = ''
    [UiSettings]
    ColorScheme=*
  '';
}
