# zen on darwin comes from the homebrew cask: the zen flake has no
# x86_64-darwin build, so programs.zen-browser and the profile it manages are
# unavailable here. the extension policy still carries over, because the
# browser reads policies from macos user defaults under its bundle id, which
# leaves the signed bundle alone. the other documented path, dropping
# policies.json into Contents/Resources/distribution, adds a file inside the
# sealed resource directory: codesign then reports "a sealed resource is
# missing or invalid" and spctl rejects the app.
{
  lib,
  pkgs,
  username,
  ...
}: {
  system = {
    defaults.CustomUserPreferences."app.zen-browser.zen" = {
      # gates the whole macos policy provider. without it the keys below are
      # still read and then discarded
      EnterprisePoliciesEnabled = true;

      ExtensionSettings = import ./_extension-policy.nix {inherit pkgs lib;};

      # grant an extension its requested host permissions at install, so mv3
      # addons like wappalyzer work everywhere instead of needing a per-site
      # click. the linux profile pins this as a plain pref, locked is the
      # policy spelling
      Preferences."extensions.originControls.grantByDefault" = {
        Value = true;
        Status = "locked";
      };
    };

    # zen's dmg ships the app without its notarization ticket stapled, so
    # gatekeeper fetches the ticket from apple on the first launch of each
    # quarantined copy, and reports a failed lookup as "apple could not
    # verify zen.app is free of malware". attaching the ticket keeps the
    # check local. homebrew replaces the bundle on upgrade and the new copy
    # arrives unstapled, so re-check every activation. stapling needs the
    # network, so report a failure instead of aborting activation.
    # TODO: drop once upstream staples its release builds
    activationScripts.postActivation.text = ''
      if [ -d /Applications/Zen.app ] && ! sudo -u ${username} xcrun stapler validate -q /Applications/Zen.app; then
        sudo -u ${username} xcrun stapler staple /Applications/Zen.app \
          || echo "zen: could not staple the notarization ticket, needs network"
      fi
    '';
  };
}
