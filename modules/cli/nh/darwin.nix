# nix-darwin has no programs.nh module. gc stays on nix.gc in platform/nix/darwin.nix
{pkgs, ...}: {
  environment.systemPackages = [pkgs.nh];
}
