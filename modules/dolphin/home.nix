{pkgs, ...}: let
  # wait for /rumboon/dolphin-overlay#4 to merge to remove.
  dolphin-wrapped = pkgs.symlinkJoin {
    name = "dolphin-wrapped";
    paths = [pkgs.kdePackages.dolphin];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      rm $out/bin/dolphin
      makeWrapper ${pkgs.kdePackages.dolphin}/bin/dolphin $out/bin/dolphin \
        --set XDG_CONFIG_DIRS "${pkgs.libsForQt5.kservice}/etc/xdg:$XDG_CONFIG_DIRS" \
        --run "${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental ${pkgs.libsForQt5.kservice}/etc/xdg/menus/applications.menu"
    '';
  };
in {
  home.packages =
    [dolphin-wrapped]
    ++ (with pkgs.kdePackages; [
      qtsvg
      kio # needed since 25.11
      kio-fuse # mount remote filesystems via FUSE
      kio-extras # extra protocols (sftp, fish, etc)

      # extensions
      ark # archive support
      audiocd-kio # audio CD support
      baloo # file tagging / search index
      dolphin-plugins # git/hg/dropbox/mount integration
      kio-admin # manage files as root
      kio-gdrive # google drive via KIO
      kompare # diff dialog
      konsole # embedded terminal panel

      # thumbnailers
      ffmpegthumbs # video
      kdegraphics-thumbnailers # images, PDFs, .blend
      kimageformats # GIMP .xcf, .heic
      qtimageformats # .webp, .tiff, .tga, .jp2
    ])
    ++ (with pkgs; [
      icoutils # .ico/.cur and embedded .exe icons
      libappimage # embedded .AppImage icons
      resvg # SVG thumbnails
      taglib # audio metadata
    ]);

  # fixes dolphin theming under non-KDE compositors (hyprland, niri)
  xdg.configFile."kdeglobals".text = ''
    [UiSettings]
    ColorScheme=*
  '';
}
