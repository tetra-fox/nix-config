# nixd settings shared by vscode and helix. nixd evaluates the `expr` strings from the flake
# root, so `./.` is the flake
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
