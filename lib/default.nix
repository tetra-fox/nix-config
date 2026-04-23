inputs: let
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

  pkgsOverlay = _: prev: let
    nixFiles = builtins.filter (lib.hasSuffix ".nix") (builtins.attrNames (builtins.readDir dirs.pkgs));
  in
    lib.listToAttrs (
      map (file: {
        name = lib.removeSuffix ".nix" file;
        value = prev.callPackage (dirs.pkgs + "/${file}") {};
      })
      nixFiles
    )
    // {
      quickshell = inputs.quickshell.packages.${prev.stdenv.hostPlatform.system}.default;
    };

  vscodeExtensionsOverlay = inputs.nix-vscode-extensions.overlays.default;

  features = let
    mkFeature = name: let
      dir = dirs.features + "/${name}";
      module = file:
        lib.optionalAttrs (builtins.pathExists (dir + "/${file}")) {
          ${lib.removeSuffix ".nix" file} = dir + "/${file}";
        };
    in
      module "system.nix" // module "home.nix";
  in
    lib.genAttrs (builtins.attrNames (
      lib.filterAttrs (_: type: type == "directory") (builtins.readDir dirs.features)
    ))
    mkFeature;

  mkHost = {
    name,
    system,
    extraModules ? [],
    extraHomeModules ? [],
  }: let
    isDarwin = lib.hasSuffix "-darwin" system;
    builder =
      if isDarwin
      then inputs.nix-darwin.lib.darwinSystem
      else inputs.nixpkgs.lib.nixosSystem;
    hmModule =
      if isDarwin
      then inputs.home-manager.darwinModules.home-manager
      else inputs.home-manager.nixosModules.home-manager;
    hostDir = dirs.hosts + "/${name}";
    quirksPath = dirs.quirks + "/${name}";
    specialArgs =
      commonArgs // lib.optionalAttrs (builtins.pathExists quirksPath) {quirks = quirksPath;};
  in
    builder {
      inherit system specialArgs;
      modules =
        [
          {nixpkgs.overlays = [vscodeExtensionsOverlay pkgsOverlay];}
          hostDir
          hmModule
          {
            home-manager = {
              users.${username}.imports = [(hostDir + "/home")] ++ extraHomeModules;
              extraSpecialArgs = commonArgs;
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bak";
            };
          }
        ]
        ++ extraModules;
    };
in
  mkHost
