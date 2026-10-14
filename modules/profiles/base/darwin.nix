{
  lib,
  modules,
  username,
  ...
}: {
  imports = [
    ./common.nix
    modules.platform.nix.darwin
    modules.services.sshd.darwin
  ];

  # nix-darwin ignores `shell` for users not in knownUsers. 501 is the first macos user
  users.knownUsers = [username];
  users.users.${username} = {
    uid = lib.mkDefault 501;
    home = "/Users/${username}";
  };

  # user-scoped system.defaults and homebrew run as this user
  system.primaryUser = username;

  # sudo via touch id; pam_reattach keeps it working inside zellij
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  # keep the nix store out of time machine
  system.activationScripts.postActivation.text = ''
    tmutil addexclusion -p /nix 2>/dev/null || true
  '';

  # no time.timeZone, macos sets it by location
}
