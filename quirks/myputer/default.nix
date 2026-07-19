{username, ...}: {
  # intel mac: x86_64-darwin is deprecated as of nixpkgs 26.05, opt in until
  # this machine is replaced with apple silicon
  nixpkgs.config.allowDeprecatedx86_64Darwin = true;

  # the fleet's home-manager follows unstable while this host pins 26.05
  # (the last x86_64-darwin release); the mismatch is deliberate, mute the nag
  home-manager.users.${username}.home.enableNixpkgsReleaseCheck = false;
}
