{ inputs }:

let
  username = "tetra";
  shared = {
    wallpapers = ../shared/wallpapers;
  };

  pkgsDir = ../pkgs;
  featuresDir = ../features;
  hostsDir = ../hosts;
  quirksDir = ../quirks;

  overlays = [
    (
      _: prev:
      let
        entries = builtins.readDir pkgsDir;
        pkgFiles = builtins.filter (n: entries.${n} == "regular" && builtins.match ".*\\.nix" n != null) (
          builtins.attrNames entries
        );
      in
      builtins.listToAttrs (
        map (n: {
          name = builtins.replaceStrings [ ".nix" ] [ "" ] n;
          value = prev.callPackage (pkgsDir + "/${n}") { };
        }) pkgFiles
      )
    )
  ];

  features =
    let
      mkFeature =
        name:
        let
          dir = featuresDir + "/${name}";
          has = file: builtins.pathExists (dir + "/${file}");
        in
        (if has "system.nix" then { system = dir + "/system.nix"; } else { })
        // (if has "home.nix" then { home = dir + "/home.nix"; } else { });
      entries = builtins.readDir featuresDir;
      dirs = builtins.filter (n: entries.${n} == "directory") (builtins.attrNames entries);
    in
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = mkFeature name;
      }) dirs
    );

  mkHM = userModules: {
    users.${username}.imports = userModules;
    extraSpecialArgs = {
      inherit
        inputs
        username
        features
        shared
        ;
    };
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
  };

  mkHost =
    {
      name,
      system,
      extraHomeModules ? [ ],
      extraModules ? [ ],
    }:
    let
      isDarwin = builtins.match ".*-darwin" system != null;
      builder = if isDarwin then inputs.nix-darwin.lib.darwinSystem else inputs.nixpkgs.lib.nixosSystem;
      hmModule =
        if isDarwin then
          inputs.home-manager.darwinModules.home-manager
        else
          inputs.home-manager.nixosModules.home-manager;
      quirksPath = quirksDir + "/${name}";
      hasQuirks = builtins.pathExists quirksPath;
      baseSpecialArgs = {
        inherit
          inputs
          username
          features
          shared
          ;
      };
      specialArgs = baseSpecialArgs // (if hasQuirks then { quirks = quirksPath; } else { });
    in
    builder {
      inherit system specialArgs;
      modules = [
        { nixpkgs.overlays = overlays; }
        (hostsDir + "/${name}")
        hmModule
        {
          home-manager = mkHM ([ (hostsDir + "/${name}/home") ] ++ extraHomeModules);
        }
      ]
      ++ extraModules;
    };

in
{
  inherit mkHost;
}
