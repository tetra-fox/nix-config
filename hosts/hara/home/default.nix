{
  pkgs,
  lib,
  modules,
  ...
}: {
  imports = [
    modules.profiles.workstation.home

    # hara-specific desktop bits (DE choice, theme, hardware-tied)
    modules.catppuccin.home
    modules.cosmic.home
    modules.dolphin.home
    modules.hyprland.home
    modules.nvidia.home
    # modules.openrgb.home
    modules.steam.home
    modules.stylix.home
    modules.surge-dm.home
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      (lib.genAttrs [
        "audio/mpeg"
        "audio/mp4"
        "audio/wav"
        "audio/x-wav"
        "audio/ogg"
        "audio/flac"
        "audio/aac"
        "audio/x-vorbis+ogg"
        "audio/x-flac"
        "audio/x-matroska"
        "audio/webm"
        "audio/opus"
        "video/mp4"
        "video/x-matroska"
        "video/webm"
        "video/quicktime"
        "video/x-msvideo"
        "video/mpeg"
        "video/x-flv"
        "video/3gpp"
      ] (_: "vlc.desktop"))
      // (lib.genAttrs [
        "image/bmp"
        "image/x-win-bitmap"
        "image/gif"
        "image/icns"
        "image/x-icon"
        "image/jpeg"
        "image/jpg"
        "image/x-portable-bitmap"
        "image/x-portable-graymap"
        "image/png"
        "image/x-portable-pixmap"
        "image/svg+xml"
        "image/tiff"
        "image/vnd.wap.wbmp"
        "image/webp"
        "image/x-xbitmap"
        "image/x-xpixmap"
        "application/x-navi-animation"
        "image/apng"
        "image/avif"
        "image/avif-sequence"
        "image/x-sgi-bw"
        "image/aces"
        "image/x-exr"
        "image/vnd.radiance"
        "image/heic"
        "image/heif"
        "image/jxl"
        "application/x-krita"
        "image/openraster"
        "image/vnd.zbrush.pcx"
        "image/x-pcx"
        "image/x-pic"
        "image/vnd.adobe.photoshop"
        "application/x-photoshop"
        "application/photoshop"
        "application/psd"
        "image/psd"
        "image/x-sun-raster"
        "image/x-rgb"
        "image/x-sgi-rgba"
        "image/sgi"
        "image/x-tga"
        "image/x-xcf"
      ] (_: "com.interversehq.qView.desktop"));
  };

  home.packages = with pkgs; [
    # creative
    cider-2
    bitwig-studio
    tenacity
    blender

    # gaming
    (prismlauncher.override {
      jdks = [
        javaPackages.compiler.temurin-bin.jre-25
        javaPackages.compiler.temurin-bin.jre-21
        javaPackages.compiler.temurin-bin.jre-17
        javaPackages.compiler.temurin-bin.jre-8
      ];
    })
    (bottles.override {removeWarningPopup = true;})
    vrcx
  ];

  # paws off!
  home.stateVersion = "26.05";
}
