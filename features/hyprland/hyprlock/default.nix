{ shared, ... }:

let
  wallpaper = toString (shared.wallpapers + "/andrei-castanha-cCWKt_dHMvQ-unsplash-rotate.jpg");
in
{
  programs.hyprlock = {
    enable = true;

    settings = {
      "$font" = "Sans-Serif";

      animations = {
        enabled = true;
        bezier = [
          "linear, 1, 1, 0, 0"
          "snap, 0.29, 1.0, 0.5, 1.0"
        ];
        animation = [
          "fadeIn, 1, 1, snap"
          "fadeOut, 1, 1, linear"
          "inputFieldDots, 1, 1, snap"
        ];
      };

      background = [
        {
          monitor = "";
          path = wallpaper;
          blur_passes = 5;
          blur_size = 4;
          brightness = 0.5;
          vibrancy = 0.15;
        }
      ];

      "input-field" = [
        {
          monitor = "";
          size = "320, 52";
          outline_thickness = 2;

          inner_color = "rgba(100814bb)";
          outer_color = "rgba(771f82cc)";
          check_color = "rgba(771f82ff) rgba(b06bceff) 45deg";
          fail_color = "rgba(cc3344ee) rgba(991122ee) 45deg";

          font_color = "rgba(f0e6f5ff)";
          fade_on_empty = false;
          rounding = 10;

          font_family = "$font";
          placeholder_text = "";
          check_text = "authenticating...";
          fail_text = "";

          dots_spacing = 0.3;
          dots_size = 0.25;

          position = "0, -130";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        # TIME
        {
          monitor = "";
          text = "$TIME";
          font_size = 120;
          font_family = "$font Bold";
          color = "rgba(ffffffff)";
          position = "0, -320";
          halign = "center";
          valign = "top";
        }
        # DATE
        {
          monitor = "";
          text = ''cmd[update:60000] date +"%A, %B %d"'';
          font_size = 24;
          font_family = "$font";
          color = "rgba(ffffff77)";
          position = "0, -520";
          halign = "center";
          valign = "top";
        }
        # USERNAME
        {
          monitor = "";
          text = "$USER";
          font_size = 14;
          font_family = "$font";
          color = "rgba(ffffff55)";
          position = "0, -55";
          halign = "center";
          valign = "center";
        }
        # FAIL
        {
          monitor = "";
          text = "$PAMFAIL";
          font_size = 13;
          font_family = "$font";
          color = "rgba(cc3344ee)";
          position = "0, -195";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };

  wayland.windowManager.hyprland.settings.bind = [
    "SUPER,ESCAPE,global,quickshell:lock"
  ];
}
