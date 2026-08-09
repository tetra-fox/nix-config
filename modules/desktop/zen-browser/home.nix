{
  username,
  config,
  lib,
  pkgs,
  ...
}: let
  customExtensions = import ./_custom-extensions.nix {inherit pkgs;};

  extensions =
    (with pkgs.nur.repos.rycee.firefox-addons; [
      ublock-origin
      wappalyzer
      onepassword-password-manager
      refined-github
      steam-database
      facebook-container
      sponsorblock
      enhancer-for-youtube
    ])
    ++ (with customExtensions; [
      scam
    ]);

  # every addon package puts its xpi under the firefox application id
  firefoxAppId = "{ec8030f7-c20a-464f-9b0e-13a3a9e97384}";

  # let the browser's own installer pull each xpi out of the store instead of
  # symlinking them into <profile>/extensions. XPIProvider decides a sideloaded
  # addon changed from its mtime and path alone, and every store file has mtime
  # 1 at a fixed profile path, so a version bump that way is invisible to the
  # addon database: it keeps the old manifest and cached content scripts while
  # loading the new xpi. installAddonFromURL compares versions instead, and
  # refuses downgrades. updates_disabled stops the browser downloading its own
  # xpi over ours, which is what made the two writers fight.
  extensionPolicy = lib.listToAttrs (map (pkg:
    lib.nameValuePair pkg.addonId {
      installation_mode = "normal_installed";
      updates_disabled = true;
      # braces are not legal in a url path, percent-encode them
      install_url =
        "file://"
        + lib.replaceStrings ["{" "}"] ["%7B" "%7D"]
        "${pkg}/share/mozilla/extensions/${firefoxAppId}/${pkg.addonId}.xpi";
    })
  extensions);
in {
  imports = [../_autostart.nix];

  options.my.zen-browser.bookmarks = lib.mkOption {
    type = with lib.types; listOf anything;
    default = [];
    description = "bookmarks in home-manager bookmarks.settings format; personal data is injected by the profile, this module stores none";
  };

  config = {
    # must be config.programs.zen-browser.finalPackage, not the raw flake package:
    # home-manager wraps it with the policies/extensions/profile settings configured below
    my.autostart.apps.zen.exec = lib.getExe config.programs.zen-browser.finalPackage;

    programs.zen-browser = {
      enable = true;

      # baked into the launcher wrapper, so it also reaches launches from
      # systemd units where home.sessionVariables would not: force the native
      # wayland backend so the fractional-scale workaround below takes effect
      env.MOZ_ENABLE_WAYLAND = "1";

      policies.ExtensionSettings = extensionPolicy;

      profiles.${username} = {
        id = 0;
        isDefault = true;

        # betterfox prefs from yokoffing's zen-specific user.js. no smoothfox
        # equivalent here: zen ships its own tuned scrolling prefs, which the
        # smoothfox sections would fight rather than improve
        presets.betterfox.enable = true;

        settings = {
          "browser.startup.homepage" = "about:blank";
          "browser.newtabpage.enabled" = false;
          "extensions.activeThemeID" = "{f2b832a9-f0f5-4532-934c-74b25eb23fb9}";
          "browser.ml.chat.shortcuts" = false;

          # grant an extension its requested host permissions at install, so
          # mv3 addons like wappalyzer work everywhere instead of needing a
          # per-site click. currently zen's default, pinned so it stays true
          "extensions.originControls.grantByDefault" = true;

          "devtools.jsonview.enabled" = true;

          # firefox's fractional-scale path renders extension popups oversized and blurry
          # on hyprland; disabling it makes them render at integer scale and downscale sharp
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
