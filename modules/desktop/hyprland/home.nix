{
  pkgs,
  config,
  lib,
  ...
}: let
  terminal = lib.getExe pkgs.kitty;
  menu = "${lib.getExe config.programs.vicinae.package} toggle";
  file_manager = "${lib.getExe' pkgs.kdePackages.dolphin "dolphin"} ~";
  main_mod = "SUPER";
in {
  imports = [
    ../_autostart.nix
    ./_hyprpaper
    ./_hyprcursor.nix
    ./_quickshell
    ./_clipboard.nix
    ./_screen-capture.nix
    ./_1password.nix
  ];

  config = {
    my.autostart.targets = ["wayland-session@hyprland.desktop.target"];

    _module.args = {
      inherit
        main_mod
        terminal
        menu
        file_manager
        ;
    };

    home.packages = with pkgs; [
      app2unit
      hyprshutdown
    ];

    # uwsm sources this into the systemd --user activation env specifically
    # for XDG_CURRENT_DESKTOP=Hyprland (uwsm/env-${desktop,,}, see prepare-env.sh),
    # and restores the prior env on session stop. this is what actually reaches
    # apps launched via app2unit (systemd units), unlike hl.env/home.sessionVariables.
    # QT_* values mirror what stylix.targets.qt.enable computes for platform "qtct"
    # (modules/desktop/stylix/home.nix pins the global default back to plasma's kde+breeze).
    # SSH_ASKPASS: plasma6.nix sets the global default to ksshaskpass (mkDefault,
    # nothing else in this repo overrides it), fine for plasma but only correct
    # there by accident; pin the same binary here explicitly so it's an intentional
    # hyprland choice too, not an inherited one
    xdg.configFile."uwsm/env-hyprland".text = ''
      export QT_QPA_PLATFORMTHEME=qt5ct
      export QT_STYLE_OVERRIDE=kvantum
      export SSH_ASKPASS=${lib.getExe' pkgs.kdePackages.ksshaskpass "ksshaskpass"}
    '';

    home.sessionVariables = {
      NIXOS_OZONE_WL = "1";

      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_DESKTOP = "Hyprland";

      GDK_BACKEND = "wayland,x11,*";
      CLUTTER_BACKEND = "wayland";

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
        # not run through replaceVars: its @DEFAULT_AUDIO_SINK@ tokens would trip the leftover-token check
        media = ./_lua/media.lua;
        bindings.content = pkgs.replaceVars ./_lua/bindings.lua {
          inherit main_mod terminal menu file_manager;
          app2unit = lib.getExe pkgs.app2unit;
          hyprpicker = "${pkgs.hyprpicker}/bin/hyprpicker";
        };
      };
    };
  };
}
