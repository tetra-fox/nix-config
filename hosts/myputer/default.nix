# 2020 13" macbook pro (intel, MacBookPro16,2)
{
  modules,
  username,
  ...
}: {
  imports = [
    modules.profiles.workstation.darwin
  ];

  networking.applicationFirewall = {
    enable = true;
    allowSigned = true;
    allowSignedApp = true;
  };

  # gui apps and mac-only tooling stay in homebrew; generic cli formulae moved
  # to nix (see home/). cleanup "uninstall" removes anything undeclared at each
  # switch but keeps app data, so brew is declarative without nuking settings
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "uninstall";
    };

    taps = [
      "rhettbull/osxphotos"
    ];

    brews = [
      "ddcctl" # external display brightness over ddc, mac-only
      "pipx" # nixpkgs pipx fails its test suite on x86_64-darwin
      "hatch" # ditto
      "libimobiledevice" # ios device pairing wants the brew build
      "rhettbull/osxphotos/osxphotos"
      "nicotine-plus" # gui app shipped as a formula, not a cask
      "podman" # backs podman-desktop
      "portaudio" # native build dep for audio tooling
      # xcode-adjacent toolchain, happier from brew than nixpkgs on darwin
      "carthage"
      "swiftformat"
      "swiftgen"
      "xcodegen"
    ];

    casks = [
      "1password-cli@beta"
      "1password@beta"
      "ableton-live-suite"
      "blackhole-2ch"
      "caldigit-thunderbolt-charging"
      "coconutbattery"
      "dbeaver-community"
      "discord"
      "elmedia-player"
      "firefox"
      "focusrite-control"
      "google-chrome"
      "grandperspective"
      "handbrake-app"
      "hex-fiend"
      "insomnia"
      "keka"
      "kicad"
      "macs-fan-control"
      "mp3tag"
      "native-access"
      "notion"
      "obs"
      "obsidian"
      "openrgb"
      "parsec"
      "plugdata"
      "prismlauncher"
      "rar"
      "raycast"
      "rectangle"
      "rekordbox"
      "signal"
      "splice"
      "spotify"
      "steam"
      "telegram"
      "temurin"
      "temurin@17"
      "tor-browser"
      "transmission"
      "ultimate-vocal-remover"
      "unnaturalscrollwheels"
      "wireshark-app"
      "xld"
      "youlean-loudness-meter"
    ];
  };

  system = {
    # captured from the pre-nix system with `defaults read`
    defaults = {
      dock = {
        autohide = false;
        magnification = false;
        show-recents = false;
        tilesize = 38;
        expose-group-apps = false;
        wvous-br-corner = 14; # bottom-right hot corner: quick note

        # captured layout; the dock is fully managed now, rearrangements
        # belong here rather than in the gui
        persistent-apps = [
          "/Applications/Firefox.app"
          "/Applications/Telegram.app"
          "/Applications/Discord.app"
          "/System/Applications/Messages.app"
          "/Applications/Notion.app"
          "/Applications/Ableton Live 12 Suite.app"
          "/Applications/rekordbox 7/rekordbox.app"
          "/Applications/DaVinci Resolve/DaVinci Resolve.app"
          "/System/Applications/Music.app"
          "/Users/${username}/Applications/Home Manager Apps/VSCodium.app"
          "/Users/${username}/Applications/Home Manager Apps/Ghostty.app"
          "/System/Applications/System Settings.app"
        ];
      };

      finder = {
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
        FXDefaultSearchScope = "SCcf"; # search the current folder, not This Mac
        FXPreferredViewStyle = "clmv"; # column view
        FXRemoveOldTrashItems = true;
        NewWindowTarget = "Home";
        ShowExternalHardDrivesOnDesktop = true;
        ShowHardDrivesOnDesktop = true;
        ShowMountedServersOnDesktop = true;
        ShowRemovableMediaOnDesktop = true;
      };

      trackpad = {
        Clicking = true; # tap to click
        TrackpadRightClick = true;
        FirstClickThreshold = 1; # medium click pressure
        SecondClickThreshold = 1;
        TrackpadThreeFingerTapGesture = 0; # no three-finger look-up
      };

      # macos tiling fully off; rectangle owns window management
      WindowManager = {
        GloballyEnabled = false; # stage manager
        EnableTiledWindowMargins = false;
        EnableTilingByEdgeDrag = false;
        EnableTilingOptionAccelerator = false;
        EnableTopTilingByEdgeDrag = false;
      };

      menuExtraClock = {
        Show24Hour = true;
        ShowDayOfWeek = true;
        ShowSeconds = true;
        ShowDate = 0; # only when space allows
      };

      loginwindow.GuestEnabled = false;

      SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;

      # set on the old system but with no first-class nix-darwin option
      CustomUserPreferences = {
        # don't litter network shares with .DS_Store
        "com.apple.desktopservices".DSDontWriteNetworkStores = true;
        # pressing fn starts dictation
        "com.apple.HIToolbox".AppleFnUsageType = 3;

        # rectangle: alternate shortcut set, hidden menubar icon, autostart,
        # repeat-to-cycle-sizes; sparkle updater state deliberately not pinned
        "com.knollsoft.Rectangle" = {
          alternateDefaultShortcuts = true;
          footprintAnimationDurationMultiplier = "0.75";
          hideMenubarIcon = true;
          launchOnLogin = true;
          subsequentExecutionMode = 1;
          reflowTodo = {
            keyCode = 45;
            modifierFlags = 786432;
          };
          toggleTodo = {
            keyCode = 11;
            modifierFlags = 786432;
          };
        };
      };

      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        AppleShowAllExtensions = true;
        AppleKeyboardUIMode = 3; # full keyboard access
        AppleICUForce24HourTime = true;
        AppleMeasurementUnits = "Centimeters";
        AppleMetricUnits = 1;
        AppleTemperatureUnit = "Celsius";
        KeyRepeat = 2;
        InitialKeyRepeat = 25;
        ApplePressAndHoldEnabled = false; # hold-to-repeat, not the accent picker
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
      };
    };

    # imperative macos state that has no nix-darwin option; everything here is
    # idempotent and was captured from the machine before nix took over
    activationScripts.postActivation.text = ''
      # verbose boot
      nvram boot-args="-v"

      # power profile, captured from `pmset -g custom`. the sleep values are the
      # exception: this machine is reachable over ssh, and a sleeping mac drops
      # the connection and won't wake on an incoming tcp syn, so never sleep on
      # ac and keep a long idle timeout on battery
      pmset -b displaysleep 2 sleep 30 disksleep 10 powernap 0 proximitywake 0 womp 0
      pmset -c displaysleep 10 sleep 0 disksleep 10 powernap 1 proximitywake 1 womp 1
      pmset -a hibernatemode 3 lidwake 1

      # ByHost prefs, which CustomUserPreferences can't reach: ctrl<->cmd swap
      # on the corsair keyboard (vendor 6940, product 7037) and screensaver
      # timing. hid usage ids: e0=lctrl e3=lcmd e4=rctrl e7=rcmd
      sudo -u ${username} defaults -currentHost write -g com.apple.keyboard.modifiermapping.6940-7037-0 -array \
        '{HIDKeyboardModifierMappingSrc=30064771299;HIDKeyboardModifierMappingDst=30064771296;}' \
        '{HIDKeyboardModifierMappingSrc=30064771303;HIDKeyboardModifierMappingDst=30064771300;}' \
        '{HIDKeyboardModifierMappingSrc=30064771300;HIDKeyboardModifierMappingDst=30064771303;}' \
        '{HIDKeyboardModifierMappingSrc=30064771296;HIDKeyboardModifierMappingDst=30064771299;}'
      sudo -u ${username} defaults -currentHost write com.apple.screensaver idleTime -int 1200
      sudo -u ${username} defaults -currentHost write com.apple.screensaver showClock -bool false
    '';

    # paws off!
    stateVersion = 6;
  };
}
