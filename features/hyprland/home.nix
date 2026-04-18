{
  pkgs,
  config,
  ...
}:

let
  terminal = "kitty";
  menu = "walker";
  browser = "firefox";
  file_manager = "dolphin";
  main_mod = "SUPER";
in
{
  imports = [
    ./hyprpaper
    ./hyprcursor.nix
    ./swaync.nix
    ./quickshell
    ./snappy-switcher
    ./clipse.nix
    ./hyprshot.nix
    ./1password.nix
    ./hyprlock
  ];

  home.packages = with pkgs; [
    app2unit
    hyprpicker
    hyprshutdown
  ];

  services.hyprpolkitagent.enable = true;

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    package = null;
    portalPackage = null;

    settings = {
      # display configuration
      monitor = [
        "DP-1,preferred,0x0,1.666"
        "DP-3,preferred,auto-left,1.666"
        "HDMI-A-3,preferred,auto-right,1.666"
      ];

      # input
      input = {
        # keyboard
        kb_layout = "us";
        numlock_by_default = true;

        # mouse
        follow_mouse = 2; # allow scroll in unfocused windows
        sensitivity = -0.5;
      };

      # keybinds
      bind = [
        "${main_mod},GRAVE,exec,app2unit --${terminal}"
        "${main_mod},E,exec,app2unit --dolphin"

        "${main_mod},SPACE,exec,${menu}" # walker
        "${main_mod},mouse:274,togglefloating"

        "${main_mod},C,exec,hyprpicker -a"

        "${main_mod},Q,killactive"
        "${main_mod},M,exec,hyprshutdown"
      ];

      bindm = [
        "${main_mod},mouse:272,movewindow" # rearrange windows with LMB
        "${main_mod},mouse:273,resizewindow" # resize windows with RMB
      ];

      bindl = [
        # media keys
        ",XF86AudioPlay,exec,playerctl play-pause"
        ",XF86AudioNext,exec,playerctl next"
        ",XF86AudioPrev,exec,playerctl previous"
        ",XF86AudioMute,exec,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ];

      bindel = [
        # media keys
        ",XF86AudioRaiseVolume,exec,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume,exec,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ];

      general = {
        gaps_in = 2;
        gaps_out = 4;

        border_size = 1;

        "col.active_border" = "rgba(ff34a8ee)";
        "col.inactive_border" = "rgba(59595922)";

        resize_on_border = false;

        allow_tearing = false;
      };

      decoration = {
        rounding = 4;
        rounding_power = 2;

        active_opacity = 1;
        inactive_opacity = 0.98;

        blur = {
          enabled = true;
          size = 8;
          passes = 1;
          brightness = 1.0;
          vibrancy = 1;
        };
      };

      animations = {
        enabled = true;

        bezier = [
          "easeOutQuint,0.23,1,0.32,1"
          "easeInOutCubic,0.65,0.05,0.36,1"
          "linear,0,0,1,1"
          "almostLinear,0.5,0.5,0.75,1"
          "quick,0.15,0,0.1,1"
        ];

        # NAME, ONOFF, SPEED, CURVE[, STYLE]
        animation = [
          "global, 1, 10, default"

          "border, 1, 5.39, easeOutQuint"

          "windows, 1, 1.2, easeOutQuint"
          "windowsIn, 1, 1.2, easeOutQuint, popin 87%"
          "windowsOut, 1, 1.2, linear, popin 87%"

          "fade, 1, 1, quick"
          "fadeIn, 1, 1.73, almostLinear"
          "fadeOut, 1, 1.46, almostLinear"

          "layers, 1, 3.81, easeOutQuint"
          "layersIn, 1, 1.5, easeOutQuint, fade"
          "layersOut, 1, 1, linear, fade"
          "fadeLayersIn, 1, 1.79, almostLinear"
          "fadeLayersOut, 1, 1.39, almostLinear"

          "workspaces, 1, 1.94, almostLinear, fade"
          "workspacesIn, 1, 1.21, almostLinear, fade"
          "workspacesOut, 1, 1.94, almostLinear, fade"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master = {
        new_status = "master";
      };

      misc = {
        force_default_wallpaper = -1;
        disable_hyprland_logo = true;
        focus_on_activate = true;
        layers_hog_keyboard_focus = true;
      };

      layerrule = [
        "match:namespace quickshell-bar,blur on,ignore_alpha 0.1"
        "match:namespace quickshell-popup,blur on,ignore_alpha 0.1"
      ];

      exec-once = [
        "app2unit --Telegram -startintray"
        "app2unit --discord --start-minimized"
        "app2unit --firefox"
      ];
    };
  };
}
