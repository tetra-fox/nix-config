# easy-hosts config. every hosts/<site>-<role>-NN dir is a server, hara and myputer are listed by hand
{
  lib,
  inputs,
  fleet,
  modules,
}: let
  username = "tetra";
  serverUsername = "admin";
  # signingKey is the 1password ssh signing key, not shared/keyring/tetra.pub
  identity = {
    name = username;
    email = "me@tetra.cool";
    signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHseoQ278Qrc45S8MUE8vwXnmdxd8OiWXViK0yHYYELz";
  };

  serverNames = lib.filter (name: fleet.site-prefix name != name) (lib.attrNames (builtins.readDir ../hosts));

  specialArgs = {
    inherit username serverUsername identity modules fleet;
    inherit (fleet) caps;
    # the ssh client turns these into per-site Host blocks
    fleetSites = lib.unique (map fleet.site-prefix serverNames);
    shared = {
      wallpapers = ../shared/wallpapers;
      keyring = ../shared/keyring;
    };
  };

  # each overlays/ file is `inputs: final: prev: {...}`
  localOverlays = map (p: import p inputs) (lib.attrValues (inputs.haumea.lib.load {
    src = ../overlays;
    loader = inputs.haumea.lib.loaders.path;
  }));

  # input modules whose options modules all over the fleet write. one-feature input modules
  # are imported by that feature's module instead
  classModules = {
    nixos = [
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
      # topology.nix reads topology.self off every nixos host
      inputs.nix-topology.nixosModules.default
      modules.platform.fleet.system
    ];
    darwin = [inputs.home-manager.darwinModules.home-manager];
  };

  quirks = name: let
    dir = ../quirks + "/${name}";
  in
    lib.optional (builtins.pathExists dir) dir;

  server = name: {
    path = ../hosts + "/${name}";
    tags = [(fleet.site-prefix name)];
    specialArgs.username = serverUsername;
    modules = quirks name;
  };
in {
  # a tag with no modules/sites/<tag>.nix should fail eval
  perTag = tag: {modules = [modules.sites.${tag}];};

  perClass = class: {modules = classModules.${class};};

  shared = {
    inherit specialArgs;
    modules = [
      # not specialArgs, so `self` doesn't leak into home-manager
      {_module.args.nixosConfigurations = inputs.self.nixosConfigurations;}
      ({config, ...}: {
        nixpkgs.overlays =
          [
            # hostPlatform, not pkgs: pkgs would depend on these overlays
            (
              if config.nixpkgs.hostPlatform.system == "x86_64-darwin"
              then inputs.nix-vscode-extensions-darwin.overlays.default
              else inputs.nix-vscode-extensions.overlays.default
            )
            inputs.quickshell.overlays.default
            inputs.nix-yazi-plugins.overlays.default
            inputs.tetra-nurpkgs.overlays.default
            # the mac's zen addons come from nur.repos.rycee too
            inputs.nur.overlays.default
          ]
          ++ localOverlays;
      })
      ({pkgs, ...}: {
        home-manager = {
          extraSpecialArgs = specialArgs // {inherit inputs;};
          useGlobalPkgs = true;
          useUserPackages = true;
          # a fixed suffix aborts the whole activation once that backup exists
          backupCommand = pkgs.writeShellScript "hm-backup" ''
            ${pkgs.coreutils}/bin/mv -- "$1" "$1.$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S).bak"
          '';
        };
      })
    ];
  };

  hosts =
    {
      hara = {
        path = ../hosts/hara;
        modules = quirks "hara";
      };

      myputer = {
        path = ../hosts/myputer;
        class = "darwin";
        nixpkgs = inputs.nixpkgs-darwin;
        modules = quirks "myputer";
      };
    }
    // lib.genAttrs serverNames server;
}
