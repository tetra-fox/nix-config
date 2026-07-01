{username, ...}: {
  # we need this here, i want browser integration to work >.<
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [username];
  };
}
