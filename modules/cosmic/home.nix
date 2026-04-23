{
  config,
  lib,
  pkgs,
  cosmicLib,
  shared,
  ...
}: {
  imports = [
    ./_catppuccin-mocha-mauve-slightlyround.nix
  ];

  systemd.user.services = {
    onepassword = {
      Unit = {
        Description = "1Password (COSMIC session)";
        PartOf = ["cosmic-session.target"];
        After = ["cosmic-session.target"];
      };
      Service = {
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
        ExecStart = "${pkgs._1password-gui}/bin/1password --silent";
      };
      Install = {
        WantedBy = ["cosmic-session.target"];
      };
    };

    discord = {
      Unit = {
        Description = "Discord (COSMIC session)";
        PartOf = ["cosmic-session.target"];
        After = ["cosmic-session.target"];
      };
      Service = {
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
        ExecStart = "${pkgs.discord}/bin/discord --start-minimized";
      };
      Install = {
        WantedBy = ["cosmic-session.target"];
      };
    };

    telegram = {
      Unit = {
        Description = "Telegram (COSMIC session)";
        PartOf = ["cosmic-session.target"];
        After = ["cosmic-session.target"];
      };
      Service = {
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
        ExecStart = "${pkgs.telegram-desktop}/bin/Telegram -startintray";
      };
      Install = {
        WantedBy = ["cosmic-session.target"];
      };
    };
  };

  wayland.desktopManager.cosmic = {
    enable = true;

    compositor = {
      active_hint = false;
      autotile_behavior = cosmicLib.cosmic.mkRON "enum" "PerWorkspace";
      focus_follows_cursor = false;
      input_default = {
        state = cosmicLib.cosmic.mkRON "enum" "Enabled";
        acceleration = cosmicLib.cosmic.mkRON "optional" {
          profile = cosmicLib.cosmic.mkRON "optional" (cosmicLib.cosmic.mkRON "enum" "Flat");
          speed = 0.6;
        };
      };
      keyboard_config = {
        numlock_state = cosmicLib.cosmic.mkRON "enum" "BootOn";
      };
      xkb_config = {
        layout = "us";
        model = "pc104";
        options = cosmicLib.cosmic.mkRON "optional" "terminate:ctrl_alt_bksp";
        repeat_delay = 600;
        repeat_rate = 40;
        rules = "";
        variant = "";
      };
    };

    appearance = {
      theme.mode = "dark";

      toolkit = {
        apply_theme_global = false;
        icon_theme = "Cosmic";
        header_size = cosmicLib.cosmic.mkRON "enum" "Standard";
        interface_density = cosmicLib.cosmic.mkRON "enum" "Standard";
        interface_font = {
          family = lib.head config.fonts.fontconfig.defaultFonts.sansSerif;
          weight = cosmicLib.cosmic.mkRON "enum" "Normal";
          stretch = cosmicLib.cosmic.mkRON "enum" "Normal";
          style = cosmicLib.cosmic.mkRON "enum" "Normal";
        };
        monospace_font = {
          family = lib.head config.fonts.fontconfig.defaultFonts.monospace;
          weight = cosmicLib.cosmic.mkRON "enum" "Normal";
          stretch = cosmicLib.cosmic.mkRON "enum" "Normal";
          style = cosmicLib.cosmic.mkRON "enum" "Normal";
        };
      };
    };

    configFile = {
      "com.system76.CosmicAudio" = {
        version = 1;
        entries = {
          amplification_sink = false;
        };
      };
      "com.system76.CosmicBackground" = {
        version = 1;
        entries = {
          same-on-all = true;
          all = {
            output = "all";
            source = (
              cosmicLib.cosmic.mkRON "enum" {
                value = ["${shared.wallpapers}/andrei-castanha-cCWKt_dHMvQ-unsplash-rotate.jpg"];
                variant = "Path";
              }
            );
            filter_by_theme = true;
            rotation_frequency = 300;
            filter_method = cosmicLib.cosmic.mkRON "enum" "Lanczos";
            scaling_mode = cosmicLib.cosmic.mkRON "enum" "Zoom";
            sampling_method = cosmicLib.cosmic.mkRON "enum" "Alphanumeric";
          };
        };
      };
    };

    applets = {
      # com.system76.CosmicAppList
      app-list.settings = {
        enable_drag_source = true;
        favorites = [
          "com.system76.CosmicFiles"
          "firefox"
          "Cider"
          "cursor"
          "com.system76.CosmicTerm"
          "com.system76.CosmicSettings"
        ];
        filter_top_levels = cosmicLib.cosmic.mkRON "optional" null;
      };
      # com.system76.CosmicAppletTime
      time.settings = {
        first_day_of_week = 6;
        military_time = true;
        show_seconds = false;
        show_weekday = true;
      };
    };

    panels = [
      {
        name = "Dock";
        anchor = cosmicLib.cosmic.mkRON "enum" "Bottom";
        anchor_gap = true;
        autohide = cosmicLib.cosmic.mkRON "optional" null;
        autohover_delay_ms = cosmicLib.cosmic.mkRON "optional" "500";
        background = cosmicLib.cosmic.mkRON "enum" "ThemeDefault";
        border_radius = 8;
        exclusive_zone = true;
        expand_to_edges = false;
        keyboard_interactivity = cosmicLib.cosmic.mkRON "enum" "OnDemand";
        layer = cosmicLib.cosmic.mkRON "enum" "Top";
        margin = 4;
        opacity = 1.0;
        output = cosmicLib.cosmic.mkRON "enum" "All";
        padding = 4;
        padding_overlap = 0.5;
        plugins_center = cosmicLib.cosmic.mkRON "optional" ["com.system76.CosmicAppList"];
        plugins_wings = cosmicLib.cosmic.mkRON "optional" (
          cosmicLib.cosmic.mkRON "tuple" [
            []
            ["com.system76.CosmicAppletMinimize"]
          ]
        );
        size = cosmicLib.cosmic.mkRON "enum" "M";
        size_center = cosmicLib.cosmic.mkRON "optional" null;
        size_wings = cosmicLib.cosmic.mkRON "optional" null;
        spacing = 0;
      }
      {
        name = "Panel";
        anchor = cosmicLib.cosmic.mkRON "enum" "Top";
        anchor_gap = false;
        autohide = cosmicLib.cosmic.mkRON "optional" null;
        autohover_delay_ms = cosmicLib.cosmic.mkRON "optional" "500";
        background = cosmicLib.cosmic.mkRON "enum" "ThemeDefault";
        border_radius = 0;
        exclusive_zone = true;
        expand_to_edges = true;
        keyboard_interactivity = cosmicLib.cosmic.mkRON "enum" "OnDemand";
        layer = cosmicLib.cosmic.mkRON "enum" "Top";
        margin = 0;
        opacity = 1.0;
        output = cosmicLib.cosmic.mkRON "enum" "All";
        padding = 0;
        padding_overlap = 0.5;
        plugins_center = cosmicLib.cosmic.mkRON "optional" ["com.system76.CosmicAppletTime"];
        plugins_wings = cosmicLib.cosmic.mkRON "optional" (
          cosmicLib.cosmic.mkRON "tuple" [
            [
              "com.system76.CosmicPanelWorkspacesButton"
              "com.system76.CosmicPanelAppButton"
            ]
            [
              "com.system76.CosmicAppletStatusArea"
              "com.system76.CosmicAppletTiling"
              "com.system76.CosmicAppletAudio"
              "com.system76.CosmicAppletBluetooth"
              "com.system76.CosmicAppletNetwork"
              "com.system76.CosmicAppletBattery"
              "com.system76.CosmicAppletNotifications"
              "com.system76.CosmicAppletPower"
            ]
          ]
        );
        size = cosmicLib.cosmic.mkRON "enum" "XS";
        size_center = cosmicLib.cosmic.mkRON "optional" null;
        size_wings = cosmicLib.cosmic.mkRON "optional" null;
        spacing = 0;
      }
    ];
  };
}
