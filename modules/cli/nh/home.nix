# where the checkout lives on a workstation. servers have none, they're deployed to
{config, ...}: {
  home.sessionVariables.NH_FLAKE = "${config.home.homeDirectory}/Documents/git/nix-config";
}
