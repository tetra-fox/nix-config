{
  pkgs,
  config,
  lib,
  ...
}: let
  terminal = "kitty";
  menu = "walker";
  browser = "firefox";
  file_manager = "dolphin ~";
  main_mod = "SUPER";
in {
  imports = [
    ./_hyprpaper
    ./_hyprcursor.nix
    ./_quickshell
    ./_clipboard.nix
    ./_screen-capture.nix
    ./_1password.nix
  ];

  options.my.hyprland.autostart = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "commands run once at hyprland startup (via hl.exec_cmd); personal app lists belong in host config, not this module";
  };

  config = {
    _module.args = {
      inherit
        main_mod
        terminal
        menu
        browser
        file_manager
        ;
    };

    home.packages = with pkgs; [
      app2unit
      hyprshutdown
    ];

    home.sessionVariables = {
      NIXOS_OZONE_WL = "1";

      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_DESKTOP = "Hyprland";

      GDK_BACKEND = "wayland,x11,*";
      CLUTTER_BACKEND = "wayland";

      # QT_QPA_PLATFORMTHEME is set by stylix
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

      extraLuaFiles =
        {
          config = ./_lua/config.lua;
          # not run through replaceVars: its @DEFAULT_AUDIO_SINK@ tokens would trip the leftover-token check
          media = ./_lua/media.lua;
          bindings.content = pkgs.replaceVars ./_lua/bindings.lua {
            inherit main_mod terminal menu file_manager;
            hyprpicker = "${pkgs.hyprpicker}/bin/hyprpicker";
          };
        }
        // lib.optionalAttrs (config.my.hyprland.autostart != []) {
          startup.content = pkgs.writeText "startup.lua" (
            "hl.on(\"hyprland.start\", function()\n"
            + lib.concatMapStrings (c: "  hl.exec_cmd(\"${c}\")\n") config.my.hyprland.autostart
            + "end)\n"
          );
        };
    };
  };
}
