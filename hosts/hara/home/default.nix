{
  pkgs,
  lib,
  modules,
  ...
}: {
  imports = [
    modules.profiles.workstation.home

    modules.desktop.catppuccin.home
    modules.desktop.cosmic.home
    modules.desktop.dolphin.home
    modules.desktop.hyprland.home
    modules.hardware.nvidia.home
    # modules.hardware.openrgb.home
    modules.desktop.steam.home
    modules.desktop.stylix.home
    modules.desktop.surge-dm.home
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      (lib.genAttrs [
        "x-scheme-handler/http"
        "x-scheme-handler/https"
        "x-scheme-handler/about"
        "x-scheme-handler/unknown"
        "text/html"
      ] (_: "firefox.desktop"))
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
    cider-2
    # TODO: re-enable once nixpkgs fetchurl can pass bitwig's new cookie/token CDN gate.
    # the 6.0.6 .deb download loops (curl error 47, max redirects) because the CDN bounces
    # any client that doesn't carry the session cookie set during the redirect handshake.
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
    })
    (bottles.override {removeWarningPopup = true;})

    # vrcx's optional OpenVR overlay inits on startup. two runtime dlopen-by-
    # short-name lookups fail under nix because neither consults a RUNPATH:
    #   - xrizer (the openvrpaths.vrpath shim, see modules/steam/home.nix)
    #     dlopens "libopenxr_loader.so" -> needs openxr-loader on the path
    #   - the .NET overlay thread (VRCXVRElectron.SetupTextures) dlopens
    #     "libEGL.so.1"/"libGL.so.1" -> needs the glvnd dispatch libs, and
    #     those in turn dlopen the nvidia vendor driver from the driver link
    # scope all of it to vrcx instead of polluting the global env. driverLink
    # is /run/opengl-driver so this tracks driver bumps.
    #
    # this gets vrcx running with a working OpenXR session and GL context, but
    # the overlay still does not render: xrizer 0.5 panics in SetOverlayTexture
    # (get_real_session_data, overlay.rs:64) because it assumes a compositor
    # session already exists, and vrcx is overlay-only so it never submits
    # frames through IVRCompositor. upstream gap, not fixable here. to actually
    # get the overlay, either wait for xrizer overlay-only support or try
    # pointing openvrpaths at opencomposite (already scaffolded in
    # modules/steam/home.nix), weighed against vrchat which is tuned for xrizer.
    (vrcx-nightly.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [makeWrapper];
      postFixup =
        (old.postFixup or "")
        + ''
          wrapProgram $out/bin/vrcx \
            --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [openxr-loader libglvnd]}:${addDriverRunpath.driverLink}/lib
        '';
    }))
  ];

  # paws off!
  home.stateVersion = "26.05";
}
