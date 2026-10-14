{username, ...}: {
  nixpkgs.config.allowDeprecatedx86_64Darwin = true;

  # home-manager follows unstable while this host pins 26.05, the last x86_64-darwin release
  home-manager.users.${username}.home.enableNixpkgsReleaseCheck = false;
}
