# the nix.serverSettings.nixd block for editor LSP config, shared by vscode and helix so the
# nixpkgs/options exprs live in one place. host-aware: hara is nixos, myputer is nix-darwin, and
# each needs its own options tree plus the nixpkgs input that host actually builds against
# (myputer uses nixpkgs-darwin, see flake.nix). the `expr` strings are evaluated by nixd itself
# against the flake root, not by this file, so `./.` resolves correctly regardless of where the
# resulting settings attrset gets assembled.
{
  pkgs,
  osConfig,
}: let
  hostName = osConfig.networking.hostName;
  flakeRoot = "(builtins.getFlake (builtins.toString ./.))";
  hostConfig =
    if pkgs.stdenv.isDarwin
    then "${flakeRoot}.darwinConfigurations.${hostName}"
    else "${flakeRoot}.nixosConfigurations.${hostName}";
  nixpkgsInput =
    if pkgs.stdenv.isDarwin
    then "nixpkgs-darwin"
    else "nixpkgs";
  classOptions =
    if pkgs.stdenv.isDarwin
    then {darwin.expr = "${hostConfig}.options";}
    else {nixos.expr = "${hostConfig}.options";};
in {
  nixpkgs.expr = "import ${flakeRoot}.inputs.${nixpkgsInput} { }";
  options =
    classOptions
    // {
      home-manager.expr = "${hostConfig}.options.home-manager.users.type.getSubOptions []";
    };
}
