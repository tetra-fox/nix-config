{
  pkgs,
  config,
  ...
}: let
  terminal = "kitty";
  menu = "walker";
  browser = "firefox";
  file_manager = "dolphin ~";
  main_mod = "SUPER";
in {
  _module.args = {
    inherit
      main_mod
      terminal
      menu
      browser
      file_manager
      ;
  };

  imports = [
    ./_hyprpaper
    ./_hyprcursor.nix
    ./_quickshell
    ./_clipboard.nix
    ./_screen-capture.nix
    ./_1password.nix
  ];

  home.packages = with pkgs; [
    app2unit
    hyprshutdown
  ];

  home.sessionVariables = {
    # electron/ozone
    NIXOS_OZONE_WL = "1";

    # xdg session
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";

    # gtk
    GDK_BACKEND = "wayland,x11,*";
    CLUTTER_BACKEND = "wayland";

    # qt (QT_QPA_PLATFORMTHEME set by stylix)
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    package = null;
    portalPackage = null;

    configType = "lua";

    extraLuaFiles = {
      config = ./_lua/config.lua;
      startup = ./_lua/startup.lua;
      # media stays unsubstituted, the @DEFAULT_AUDIO_SINK@ wpctl targets
      # would trip replaceVars' leftover-token check
      media = ./_lua/media.lua;
      bindings.content = pkgs.replaceVars ./_lua/bindings.lua {
        inherit main_mod terminal menu file_manager;
        hyprpicker = "${pkgs.hyprpicker}/bin/hyprpicker";
      };
    };
  };
}
