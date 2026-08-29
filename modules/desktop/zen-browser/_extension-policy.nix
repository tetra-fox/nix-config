# the addon set shared by every host that runs zen, as an ExtensionSettings
# policy. kept out of home.nix because the mac installs zen from the homebrew
# cask and cannot evaluate the home-manager module, but a policy applies to a
# stock app bundle just as well (see darwin.nix)
{
  pkgs,
  lib,
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
in
  # let the browser's own installer pull each xpi out of the store instead of
  # symlinking them into <profile>/extensions. XPIProvider decides a sideloaded
  # addon changed from its mtime and path alone, and every store file has mtime
  # 1 at a fixed profile path, so a version bump that way is invisible to the
  # addon database: it keeps the old manifest and cached content scripts while
  # loading the new xpi. installAddonFromURL compares versions instead, and
  # refuses downgrades. updates_disabled stops the browser downloading its own
  # xpi over ours, which is what made the two writers fight.
  lib.listToAttrs (map (pkg:
    lib.nameValuePair pkg.addonId {
      installation_mode = "normal_installed";
      updates_disabled = true;
      # braces are not legal in a url path, percent-encode them
      install_url =
        "file://"
        + lib.replaceStrings ["{" "}"] ["%7B" "%7D"]
        "${pkg}/share/mozilla/extensions/${firefoxAppId}/${pkg.addonId}.xpi";
    })
  extensions)
