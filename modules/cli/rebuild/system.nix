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
    # remote deploys from the mac
    ++ lib.optionals pkgs.stdenv.isDarwin [pkgs.nixos-rebuild-ng];
}
