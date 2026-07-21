# darwin face of the base profile. boot, trim and the oom killer are the OS's
# problem on a mac; sshd is macos Remote Login, hardened to fleet policy by
# the sshd darwin module
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

  # nix-darwin only manages users listed in knownUsers; without this the zsh
  # module's `shell` assignment is ignored. 501 is the first macos user
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

  # every mac backs up with time machine sooner or later; never let it drag
  # the nix store along. idempotent, runs each activation
  system.activationScripts.postActivation.text = ''
    tmutil addexclusion -p /nix 2>/dev/null || true
  '';

  # no time.timeZone: macos sets it by location (timezone.auto is on), and a
  # pinned zone would fight that at every activation on a travelling laptop
}
