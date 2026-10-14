# separate from home.nix so darwin.nix can use it without the hm module
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

  # addon packages install under firefox's app id
  firefoxAppId = "{ec8030f7-c20a-464f-9b0e-13a3a9e97384}";
in
  # installed by url instead of symlinked into the profile: XPIProvider detects
  # sideloaded changes by mtime and path, store files are all mtime 1, so version
  # bumps go unseen. updates_disabled stops the browser fetching its own xpi
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
