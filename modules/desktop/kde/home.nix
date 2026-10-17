{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  sans = config.stylix.fonts.sansSerif.name;
  mono = config.stylix.fonts.monospace.name;
  trayShown = [
    "org.kde.plasma.volume"
    "org.kde.plasma.bluetooth"
    "org.kde.plasma.brightness"
    "org.kde.plasma.networkmanagement"
    "org.kde.plasma.clipboard"
  ];
in {
  imports = [
    ../_autostart.nix
    inputs.plasma-manager.homeModules.plasma-manager
  ];

  my.autostart.targets = ["plasma-workspace.target"];

  # plasma-manager writes only the keys set here, each activation, through kwriteconfig.
  # everything else stays editable from systemsettings
  programs.plasma = {
    enable = true;

    workspace = {
      lookAndFeel = "org.kde.breezedark.desktop";
      wallpaper = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Nuvole/";
    };

    fonts = {
      general = {
        family = sans;
        pointSize = 10;
      };
      fixedWidth = {
        family = mono;
        pointSize = 10;
      };
      small = {
        family = sans;
        pointSize = 8;
      };
      toolbar = {
        family = sans;
        pointSize = 10;
      };
      menu = {
        family = sans;
        pointSize = 10;
      };
      windowTitle = {
        family = sans;
        pointSize = 10;
      };
    };

    panels = [
      {
        location = "bottom";
        height = 46;
        floating = true;
        widgets = [
          {
            kickoff = {
              sortAlphabetically = true;
              compactDisplayStyle = true;
              settings.General = {
                highlightNewlyInstalledApps = false;
                switchCategoryOnHover = true;
              };
            };
          }
          "org.kde.plasma.pager"
          {iconTasks.launchers = ["preferred://browser"];}
          "org.kde.plasma.marginsseparator"
          {
            systemTray.items = {
              shown = trayShown;
              # without weather. shown items have to be listed here too
              extra =
                trayShown
                ++ [
                  "org.kde.plasma.cameraindicator"
                  "org.kde.plasma.notifications"
                  "org.kde.plasma.manage-inputmethod"
                  "org.kde.plasma.mediacontroller"
                  "org.kde.plasma.devicenotifier"
                  "org.kde.kscreen"
                  "org.kde.plasma.keyboardlayout"
                  "org.kde.plasma.printmanager"
                  "org.kde.plasma.battery"
                  "org.kde.plasma.keyboardindicator"
                ];
            };
          }
          {
            digitalClock = {
              date = {
                format = "isoDate";
                position = "belowTime";
              };
              font = {
                family = sans;
                weight = 400;
                style = "Regular";
                size = 10;
              };
            };
          }
          "org.kde.plasma.showdesktop"
        ];
      }
    ];

    shortcuts = {
      kwin = {
        "Kill Window" = "Meta+Q";
        Overview = "Meta+Tab";
        "Walk Through Windows" = "Alt+Tab";
      };
      # frees Meta+Q for Kill Window
      plasmashell."manage activities" = [];
    };

    hotkeys.commands.vicinae = {
      key = "Meta+Space";
      command = "${lib.getExe config.programs.vicinae.package} toggle";
    };

    powerdevil.AC.autoSuspend.action = "nothing";

    kwin = {
      nightLight.enable = true;
      effects.windowOpenClose.animation = "glide";
    };

    input = {
      keyboard.repeatRate = 60;
      mice = [
        {
          name = "Logitech G502";
          vendorId = "046d";
          productId = "407f";
          acceleration = 0.6;
          accelerationProfile = "none";
        }
      ];
    };

    configFile = {
      kdeglobals = {
        General = {
          TerminalApplication = "kitty";
          TerminalService = "kitty.desktop";
          XftAntialias = true;
          XftHintStyle = "hintmedium";
          XftSubPixel = "none";
        };
        KDE.AnimationDurationFactor = 0.75;
      };

      # any kde app (dolphin under hyprland too) dbus-activates kded6, whose gtkconfig
      # module overwrites stylix's gtk files and dconf keys with breeze light colors.
      # gtkconfig can't be excluded, it's not an optional plasma6 package
      kded6rc.Module-gtkconfig.autoload = false;

      baloofilerc."Basic Settings"."Indexing-Enabled" = false;

      # pam_kwallet is off in system.nix, this stops the first-use wizard
      kwalletrc.Wallet = {
        Enabled = false;
        "First Use" = false;
      };

      kwriterc = {
        General."Show Menu Bar" = false;
        "KTextEditor Renderer"."Text Font" = "${mono},12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0";
      };
    };
  };
}
