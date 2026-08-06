{username, ...}: {
  # we need this here, i want browser integration to work >.<
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [username];
  };

  # zen is not on 1password's built-in browser allowlist, so native messaging
  # only connects if the running binary's name is listed here. the wrapped
  # package execs .zen-wrapped regardless of channel
  # https://github.com/0xc000022070/zen-browser-flake#1password
  environment.etc."1password/custom_allowed_browsers" = {
    text = ".zen-beta-wrapped";
    mode = "0755";
  };
}
