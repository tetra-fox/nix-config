{ username, ... }:

{
  # we need this here, i want browser integration to work >.<
  programs._1password.enable = true; # cli
  programs._1password-gui = {
    enable = true;
    # this makes system auth etc. work properly
    polkitPolicyOwners = [ username ];
  };
}
