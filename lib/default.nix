inputs:

let
  inherit (inputs.nixpkgs) lib;

  username = "tetra";
  shared.wallpapers = ../shared/wallpapers;

  dirs = {
    pkgs = ../pkgs;
    features = ../features;
    hosts = ../hosts;
    quirks = ../quirks;
  };

  commonArgs = {
    inherit
      inputs
      username
      features
      shared
      ;
  };

  # auto-overlay: every .nix file in pkgs/ becomes a package, plus flake-sourced packages
  pkgsOverlay =
    _: prev:
    let
      nixFiles = lib.pipe (builtins.readDir dirs.pkgs) [
        (lib.filterAttrs (_: type: type == "regular"))
        builtins.attrNames
        (builtins.filter (lib.hasSuffix ".nix"))
      ];
    in
    lib.listToAttrs (
      map (file: {
        name = lib.removeSuffix ".nix" file;
        value = prev.callPackage (dirs.pkgs + "/${file}") { };
      }) nixFiles
    )
    // {
      snappy-switcher = inputs.snappy-switcher.packages.${prev.stdenv.hostPlatform.system}.default;
      quickshell = inputs.quickshell.packages.${prev.stdenv.hostPlatform.system}.default;
    };

  # feature discovery: each directory in features/ may contain system.nix and/or home.nix
  features =
    let
      featureNames = lib.pipe (builtins.readDir dirs.features) [
        (lib.filterAttrs (_: type: type == "directory"))
        builtins.attrNames
      ];
      mkFeature =
        name:
        let
          dir = dirs.features + "/${name}";
          addModule =
            file:
            lib.optionalAttrs (builtins.pathExists (dir + "/${file}")) {
              ${lib.removeSuffix ".nix" file} = dir + "/${file}";
            };
        in
        addModule "system.nix" // addModule "home.nix";
    in
    lib.genAttrs featureNames mkFeature;

  mkHomeManager = homeModules: {
    home-manager = {
      users.${username}.imports = homeModules;
      extraSpecialArgs = commonArgs;
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "bak";
    };
  };

  mkHost =
    {
      name,
      system,
      extraModules ? [ ],
      extraHomeModules ? [ ],
    }:
    let
      isDarwin = lib.hasSuffix "-darwin" system;
      builder = if isDarwin then inputs.nix-darwin.lib.darwinSystem else inputs.nixpkgs.lib.nixosSystem;
      hmModule =
        if isDarwin then
          inputs.home-manager.darwinModules.home-manager
        else
          inputs.home-manager.nixosModules.home-manager;
      hostDir = dirs.hosts + "/${name}";
      quirksPath = dirs.quirks + "/${name}";
      specialArgs =
        commonArgs // lib.optionalAttrs (builtins.pathExists quirksPath) { quirks = quirksPath; };
    in
    builder {
      inherit system specialArgs;
      modules = [
        { nixpkgs.overlays = [ pkgsOverlay ]; }
        hostDir
        hmModule
        (mkHomeManager ([ (hostDir + "/home") ] ++ extraHomeModules))
      ]
      ++ extraModules;
    };

in
{
  inherit mkHost;
}
