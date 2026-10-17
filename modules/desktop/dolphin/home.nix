{
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}: {
  imports = [inputs.plasma-manager.homeModules.plasma-manager];

  home.packages =
    # plasma6 installs these system-wide
    lib.optionals (!osConfig.services.desktopManager.plasma6.enable) (with pkgs.kdePackages; [
      dolphin
      qtsvg
      kio
      kio-fuse
      kio-extras
      ark
      baloo
      dolphin-plugins # git/hg/dropbox/mount integration
      kio-admin
      konsole
      ffmpegthumbs
      kdegraphics-thumbnailers
      kimageformats # GIMP .xcf, .heic
      qtimageformats # .webp, .tiff, .tga, .jp2
    ])
    ++ (with pkgs.kdePackages; [
      audiocd-kio
      kio-gdrive
      kompare
    ])
    ++ (with pkgs; [
      icoutils # .ico, .cur, embedded .exe icons
      libappimage # embedded .AppImage icons
      resvg
      taglib
    ]);

  # plasma-manager writes keys in place, so dolphin's own settings dialog keeps working.
  # enabled here too because dolphin runs under hyprland without the kde module
  programs.plasma = {
    enable = true;

    configFile = {
      dolphinrc = {
        General.DoubleClickViewAction = "none";
        MainWindow.MenuBar = "Disabled";
        UiSettings.ColorScheme = "BreezeDark";
        DetailsMode = {
          PreviewSize = 80;
          LeftPadding = 0;
          RightPadding = 0;
        };
        IconsMode = {
          PreviewSize = 48;
          TextWidthIndex = 0;
        };
        "KFileDialog Settings" = {
          "Places Icons Auto-resize" = false;
          "Places Icons Static Size" = 22;
        };
        PreviewSettings.Plugins = builtins.concatStringsSep "," [
          "appimagethumbnail"
          "audiothumbnail"
          "comicbookthumbnail"
          "cursorthumbnail"
          "djvuthumbnail"
          "ebookthumbnail"
          "exrthumbnail"
          "directorythumbnail"
          "imagethumbnail"
          "jpegthumbnail"
          "kraorathumbnail"
          "windowsexethumbnail"
          "windowsimagethumbnail"
          "opendocumentthumbnail"
          "svgthumbnail"
        ];
      };

      kservicemenurc.Show = {
        forgetfileitemaction = true;
        hidefileitemaction = false;
        kactivitymanagerd_fileitem_linking_plugin = true;
        movetonewfolderitemaction = true;
        setfoldericonitemaction = true;
        tagsfileitemaction = true;
      };

      arkrc.MainWindow.StatusBar = "Disabled";
    };
  };
}
