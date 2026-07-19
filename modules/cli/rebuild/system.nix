# the `rebuild` wrapper for machines the user drives (linux and darwin; the
# script picks nixos-rebuild or darwin-rebuild at runtime). the remote-deploy
# user comes from the flake's serverUsername, substituted at build so the
# script and the per-host specialArgs can't drift
{
  lib,
  pkgs,
  serverUsername,
  ...
}: {
  environment.systemPackages =
    [
      (pkgs.writeShellScriptBin "rebuild" (builtins.replaceStrings ["@deployUser@"] [serverUsername] (builtins.readFile ./_rebuild.sh)))
    ]
    # nixos comes with nixos-rebuild; the mac needs it installed for remote
    # fleet deploys (eval local, build on the target)
    ++ lib.optionals pkgs.stdenv.isDarwin [pkgs.nixos-rebuild-ng];
}
