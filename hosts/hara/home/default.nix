{
  pkgs,
  lib,
  modules,
  ...
}: let
  # xrizer and vrcx's overlay thread dlopen openxr_loader and libEGL/libGL by short name,
  # which ignores RUNPATH. the overlay still won't render: xrizer 0.5 panics in
  # SetOverlayTexture for overlay-only apps
  vrcx = pkgs.vrcx-nightly.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.makeWrapper];
    postFixup =
      (old.postFixup or "")
      + ''
        wrapProgram $out/bin/vrcx \
          --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [pkgs.openxr-loader pkgs.libglvnd]}:${pkgs.addDriverRunpath.driverLink}/lib
      '';
  });
in {
  imports = [
    modules.profiles.workstation.home

    modules.cli.opencode.home
    modules.desktop.catppuccin.home
    modules.desktop.dolphin.home
    modules.desktop.hyprland.home
    modules.desktop.kde.home
    modules.hardware.nvidia.home
    # modules.hardware.openrgb.home
    modules.desktop.steam.home
    modules.desktop.sunshine.home
    modules.desktop.stylix.home
    modules.desktop.surge-dm.home
  ];

  my.autostart.apps.vrcx = {
    exec = "${lib.getExe vrcx} --no-sandbox --startup";
    tray = true;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      (lib.genAttrs [
        "x-scheme-handler/http"
        "x-scheme-handler/https"
        "x-scheme-handler/about"
        "x-scheme-handler/unknown"
        "text/html"
        "application/xhtml+xml"
      ] (_: "zen-beta.desktop"))
      // (lib.genAttrs [
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
        "audio/x-aiff"
        "audio/x-ape"
        "audio/x-wavpack"
        "audio/x-tta"
        "audio/x-musepack"
        "audio/x-ms-wma"
        "audio/x-speex"
        "audio/ac3"
        "audio/midi"
        "audio/vnd.rn-realaudio"
        "audio/x-mpegurl"
        "audio/x-scpls"
        "audio/x-dsf"
        "audio/x-tak"
        "audio/x-speex+ogg"
        "audio/x-flac+ogg"
        "video/mp4"
        "video/x-matroska"
        "video/webm"
        "video/quicktime"
        "video/x-msvideo"
        "video/mpeg"
        "video/x-flv"
        "video/3gpp"
        "video/mp2t"
        "application/mxf"
      ] (_: "vlc.desktop"))
      // (lib.genAttrs [
        "image/bmp"
        "image/x-win-bitmap"
        "image/gif"
        "image/x-icns"
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
        "image/qoi"
        "image/x-portable-anymap"
        "image/x-eps"
        "image/svg+xml-compressed"
        "image/x-adobe-dng"
        "image/x-canon-cr2"
        "image/x-canon-cr3"
        "image/x-nikon-nef"
        "image/x-sony-arw"
        "image/x-fuji-raf"
        "image/x-olympus-orf"
        "image/x-panasonic-rw"
        "image/x-panasonic-rw2"
        "image/x-pentax-pef"
      ] (_: "com.interversehq.qView.desktop"))
      # kate claims text/plain at InitialPreference=9, which wins every text subtype left undeclared
      // (lib.genAttrs [
        "text/plain"
        "application/x-zerosize"
        "text/markdown"
        "text/x-log"
        "text/x-patch"
        "application/json"
        "application/yaml"
        "application/toml"
        "application/xml"
        "application/sql"
        "text/css"
        "text/javascript"
        "text/x-shellscript"
        "text/x-python"
        "text/x-python3"
        "text/x-nix"
        "text/rust"
        "text/x-go"
        "text/x-lua"
        "text/x-java"
        "text/x-csrc"
        "text/x-chdr"
        "text/x-c++src"
        "text/x-c++hdr"
        "text/x-cmake"
        "text/x-makefile"
        "text/x-qml"
        "text/x-tex"
      ] (_: "codium.desktop"))
      // {"application/epub+zip" = "okularApplication_epub.desktop";};
  };

  home.packages = with pkgs; [
    cider-2
    # TODO: re-enable once fetchurl passes bitwig's cookie CDN gate (6.0.6 loops, curl error 47)
    # bitwig-studio
    tenacity
    blender

    (prismlauncher.override {
      jdks = [
        javaPackages.compiler.temurin-bin.jre-25
        javaPackages.compiler.temurin-bin.jre-21
        javaPackages.compiler.temurin-bin.jre-17
        javaPackages.compiler.temurin-bin.jre-8
      ];
      # waylandcraft links libxkbcommon.so.0 and also runs xkbcli, both in this one output
      additionalLibs = [libxkbcommon];
      additionalPrograms = [libxkbcommon];
    })

    vrcx
  ];

  # paws off!
  home.stateVersion = "26.05";
}
