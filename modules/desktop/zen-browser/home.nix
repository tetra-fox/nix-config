{
  username,
  config,
  lib,
  pkgs,
  ...
}: let
  extensionPolicy = import ./_extension-policy.nix {inherit pkgs lib;};
in {
  imports = [../_autostart.nix];

  options.my.zen-browser.bookmarks = lib.mkOption {
    type = with lib.types; listOf anything;
    default = [];
    description = "bookmarks in home-manager bookmarks.settings format; personal data is injected by the profile, this module stores none";
  };

  config = {
    # finalPackage, not the flake package: it carries the policies configured below
    my.autostart.apps.zen.exec = lib.getExe config.programs.zen-browser.finalPackage;

    programs.zen-browser = {
      enable = true;

      # in the wrapper so systemd launches get it too. the fractional-scale pref
      # below only applies on native wayland
      env.MOZ_ENABLE_WAYLAND = "1";

      policies.ExtensionSettings = extensionPolicy;

      profiles.${username} = {
        id = 0;
        isDefault = true;

        # no smoothfox, zen ships its own scrolling prefs
        presets.betterfox.enable = true;

        settings = {
          "browser.startup.homepage" = "about:blank";
          "browser.newtabpage.enabled" = false;
          "extensions.activeThemeID" = "{f2b832a9-f0f5-4532-934c-74b25eb23fb9}";
          "browser.ml.chat.shortcuts" = false;

          # mv3 addons get their host permissions without a per-site click.
          # already zen's default, pinned
          "extensions.originControls.grantByDefault" = true;

          "devtools.jsonview.enabled" = true;

          # fractional scaling renders extension popups oversized and blurry on hyprland
          # https://bugzilla.mozilla.org/show_bug.cgi?id=1849109
          "widget.wayland.fractional-scale.enabled" = false;

          "media.eme.enabled" = true;
          "media.gmp-widevinecdm.enabled" = true;

          "signon.rememberSignons" = false;
          "extensions.formautofill.addresses.enabled" = false;
          "extensions.formautofill.creditCards.enabled" = false;
          "browser.download.always_ask_before_handling_new_types" = false;
        };

        bookmarks = {
          force = true;
          settings = config.my.zen-browser.bookmarks;
        };
      };
    };
  };
}
