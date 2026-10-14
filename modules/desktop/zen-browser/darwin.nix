# zen comes from the homebrew cask here, the zen flake has no x86_64-darwin build.
# policies go through user defaults because a policies.json inside the bundle breaks
# its codesign seal and spctl rejects the app
{
  lib,
  pkgs,
  username,
  ...
}: {
  system = {
    defaults.CustomUserPreferences."app.zen-browser.zen" = {
      # without this the keys below are read and discarded
      EnterprisePoliciesEnabled = true;

      ExtensionSettings = import ./_extension-policy.nix {inherit pkgs lib;};

      # policy form of the pref pinned in home.nix
      Preferences."extensions.originControls.grantByDefault" = {
        Value = true;
        Status = "locked";
      };
    };

    # the dmg isn't stapled, so gatekeeper fetches the notarization ticket on first
    # launch and a failed lookup reads as a malware warning. brew upgrades replace
    # the bundle, so check every activation. stapling needs network, warn on failure
    # TODO: drop once upstream staples its release builds
    activationScripts.postActivation.text = ''
      if [ -d /Applications/Zen.app ] && ! sudo -u ${username} xcrun stapler validate -q /Applications/Zen.app; then
        sudo -u ${username} xcrun stapler staple /Applications/Zen.app \
          || echo "zen: could not staple the notarization ticket, needs network"
      fi
    '';
  };
}
