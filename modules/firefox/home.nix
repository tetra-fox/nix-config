{
  username,
  pkgs,
  inputs,
  ...
}: let
  customExtensions = import ./_custom-extensions.nix {inherit pkgs;};
in {
  # firefox creates a fresh profile every time its nix-store path changes
  # unless we opt out of dedicated-profile-per-install
  home.sessionVariables.MOZ_LEGACY_PROFILES = "1";

  programs.firefox = {
    enable = true;
    package = pkgs.firefox;

    betterfox = {
      enable = true;
      profiles.${username} = {
        enableAllSections = true;
        settings.smoothfox.natural-smooth-scrolling-v3.enable = true;
      };
    };

    profiles.${username} = {
      id = 0;
      isDefault = true;

      settings = {
        "browser.startup.homepage" = "about:blank";
        "browser.newtabpage.enabled" = false;
        "extensions.autoDisableScopes" = 0;
        "extensions.activeThemeID" = "{f2b832a9-f0f5-4532-934c-74b25eb23fb9}";
        "browser.ml.chat.shortcuts" = false;

        "devtools.jsonview.enabled" = false;

        "media.eme.enabled" = true;
        "media.gmp-widevinecdm.enabled" = true;

        "signon.rememberSignons" = false;
        "extensions.formautofill.addresses.enabled" = false;
        "extensions.formautofill.creditCards.enabled" = false;
        "browser.download.always_ask_before_handling_new_types" = false;
        "browser.uiCustomization.state" = builtins.toJSON {
          placements = {
            "widget-overflow-fixed-list" = [];
            "unified-extensions-area" = [
              "sponsorblocker_ajay_app-browser-action"
              "wappalyzer_crunchlabz_com-browser-action"
              "addon_darkreader_org-browser-action"
              "_contain-facebook-browser-action"
              "_a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad_-browser-action"
              "firefox-extension_steamdb_info-browser-action"
              "_7a7a4a92-a2a0-41d1-9fd7-1e92480d612d_-browser-action"
              "surge_surge-downloader_com-browser-action"
              "enhancerforyoutube_maximerf_addons_mozilla_org-browser-action"
            ];
            "nav-bar" = [
              "back-button"
              "forward-button"
              "stop-reload-button"
              "vertical-spacer"
              "urlbar-container"
              "_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action"
              "ublock0_raymondhill_net-browser-action"
              "downloads-button"
              "unified-extensions-button"
            ];
            "toolbar-menubar" = ["menubar-items"];
            TabsToolbar = [
              "tabbrowser-tabs"
              "new-tab-button"
            ];
            "vertical-tabs" = [];
            PersonalToolbar = [
              "personal-bookmarks"
            ];
          };
          seen = [
            "developer-button"
            "screenshot-button"
            "wappalyzer_crunchlabz_com-browser-action"
            "_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action"
            "addon_darkreader_org-browser-action"
            "_contain-facebook-browser-action"
            "_a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad_-browser-action"
            "sponsorblocker_ajay_app-browser-action"
            "firefox-extension_steamdb_info-browser-action"
            "_7a7a4a92-a2a0-41d1-9fd7-1e92480d612d_-browser-action"
            "ublock0_raymondhill_net-browser-action"
          ];
          dirtyAreaCache = [
            "nav-bar"
            "vertical-tabs"
            "PersonalToolbar"
            "toolbar-menubar"
            "TabsToolbar"
            "unified-extensions-area"
          ];
          currentVersion = 23;
          newElementCount = 4;
        };
      };

      bookmarks = {
        force = true;
        settings = inputs.nix-secrets.lib.firefox-bookmarks;
      };

      extensions = {
        force = true;
        packages =
          (with pkgs.nur.repos.rycee.firefox-addons; [
            ublock-origin
            wappalyzer
            darkreader
            stylus
            onepassword-password-manager
            refined-github
            steam-database
            facebook-container
            sponsorblock
            enhancer-for-youtube
          ])
          ++ (with customExtensions; [
            scam
            matte-black
            surge
            json-alexander
          ]);

        settings = {
          "stylus".settings = {
            dbInChromeStorage = true;
          };
        };
      };
    };
  };
}
