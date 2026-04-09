{ pkgs, config, ... }:

let
  terminal = "kitty";
  menu = "walker";
  browser = "firefox";
  file_manager = "dolphin";
  main_mod = "SUPER";

  uapp = cmd: "uwsm app -- ${cmd}";
  uservice = cmd: "uwsm app -t service -- ${cmd}";

  clipse = "hyprctl clients -j | jq -e \'.[] | select(.class==\"clipse\")\' >/dev/null && hyprctl dispatch killwindow class:clipse || kitty --class clipse -e clipse";
in
{
  imports = [
    ./hyprpaper
    ./hyprcursor.nix
  ];

  home.packages = with pkgs; [
    hyprpicker
    hyprshutdown
    wl-clipboard # needed for clipse
  ];

  programs.hyprshot.enable = true;

  services = {
    clipse.enable = true;
    hyprpolkitagent.enable = true;
  };

  # ensure that session variables are passed to uwsm-managed apps
  xdg.configFile."uwsm/env".source =
    "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    package = null;
    portalPackage = null;

    settings = {
      # environment variables
      env = [
        "LIBVA_DRIVER_NAME=nvidia"
        "__GLX_VENDOR_LIBRARY_NAME=nvidia"
      ];

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
        # apps (uwsm app -- … keeps them under the systemd session, not Hyprland's cgroup)
        "${main_mod},GRAVE,exec,${uapp terminal}"
        "${main_mod},E,exec,${uapp "org.kde.dolphin.desktop"}"
        "${main_mod},SPACE,exec,${uapp menu}"
        # hyprctl toggle / kill — not a plain app spawn
        "${main_mod},V,exec,${clipse}"

        "${main_mod},mouse:274,togglefloating"

        "${main_mod},C,exec,${uapp "hyprpicker -a"}"
        "L_Control&L_Shift,3,exec,${uapp "hyprshot -m output -m active -z --clipboard-only"}"
        "L_Control&L_Shift,4,exec,${uapp "hyprshot -m region -z --clipboard-only"}"

        "L_Control&L_Shift,SPACE,exec,${uapp "1password --quick-access"}"
        "L_Control,BACKSLASH,exec,${uapp "1password --fill"}"

        "${main_mod},Q,killactive" # close window
        # session / power UI — leave outside uwsm app
        "${main_mod},M,exec,hyprshutdown"
      ];

      bindm = [
        "${main_mod},mouse:272,movewindow" # rearrange windows with LMB
        "${main_mod},mouse:273,resizewindow" # resize windows with RMB
      ];

      general = {
        gaps_in = 2;
        gaps_out = 4;

        border_size = 1;

        "col.active_border" = "rgba(771f82ee)";
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
          size = 3;
          passes = 3;
          vibrancy = 0.1696;
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
          "layersIn, 1, 2, easeOutQuint, fade"
          "layersOut, 1, 1.5, linear, fade"
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
      };

      windowrule = [
        "match:class clipse, float on, size 622 652, pin on"
      ];

      layerrule = [
        # "blur,waybar"
      ];

      # autolaunch (uwsm app -- …); polkit stays a normal user service
      exec-once = [
        "systemctl --user enable --now hyprpolkitagent.service"
        "${uservice "waybar"}"
        "${uapp "1password --silent"}"
        "${uapp "telegram-desktop -startintray"}"
        "${uapp "discord --start-minimized"}"
        "${uservice "firefox.desktop"}"
      ];
    };
  };
}
