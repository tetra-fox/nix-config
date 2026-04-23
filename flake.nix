{
  inputs = {
    # framework
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    # separate pin for x86_64-darwin — nixpkgs 26.05 is the last release to support it
    # once pins diverge, shared inputs need to follow nixpkgs-darwin or be duplicated
    nixpkgs-darwin.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    haumea = {
      url = "github:nix-community/haumea";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    easy-hosts.url = "github:tgirlcloud/easy-hosts";

    # package sets & overlays
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # tooling
    alejandra = {
      url = "github:kamadorueda/alejandra";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixos / home-manager modules
    betterfox-nix = {
      url = "github:HeitorAugustoLN/betterfox-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cosmic-manager = {
      url = "github:HeitorAugustoLN/cosmic-manager";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    catppuccin.url = "github:catppuccin/nix";

    # fonts
    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";

    # desktop & shell
    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    elephant.url = "github:abenz1267/elephant";
    walker = {
      url = "github:abenz1267/walker";
      inputs.elephant.follows = "elephant";
    };
    zsh-patina = {
      url = "github:michel-kraemer/zsh-patina";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # private
    nix-secrets.url = "git+ssh://git@github.com/tetra-fox/nix-secrets.git";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} (let
      inherit (inputs.nixpkgs) lib;
      username = "tetra";

      pkgsOverlay = _: prev:
        prev.lib.packagesFromDirectoryRecursive {
          inherit (prev) callPackage;
          directory = ./pkgs;
        };

      commonSpecialArgs = {
        inherit username;
        modules = inputs.haumea.lib.load {
          src = ./modules;
          loader = inputs.haumea.lib.loaders.path;
        };
        shared.wallpapers = ./shared/wallpapers;
      };
    in {
      imports = [
        inputs.easy-hosts.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem = {
        inputs',
        pkgs,
        ...
      }: {
        formatter = inputs'.alejandra.packages.default;
        packages = lib.filterAttrs (_: lib.meta.availableOn pkgs.stdenv.hostPlatform) (
          pkgs.lib.packagesFromDirectoryRecursive {
            inherit (pkgs) callPackage;
            directory = ./pkgs;
          }
        );
      };

      easy-hosts = {
        shared = {
          specialArgs = commonSpecialArgs;
          modules = [
            {
              nixpkgs.overlays = [
                inputs.nix-vscode-extensions.overlays.default
                inputs.quickshell.overlays.default
                pkgsOverlay
              ];
            }
            {
              home-manager = {
                extraSpecialArgs = commonSpecialArgs // {inherit inputs;};
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "bak";
              };
            }
          ];
        };

        perClass = class: {
          modules =
            {
              nixos = [inputs.home-manager.nixosModules.home-manager];
              darwin = [inputs.home-manager.darwinModules.home-manager];
            }
            .${
              class
            } or [
            ];
        };

        hosts = {
          hara = {
            path = ./hosts/hara;
            arch = "x86_64";
            class = "nixos";
            specialArgs = lib.optionalAttrs (builtins.pathExists ./quirks/hara) {
              quirks = ./quirks/hara;
            };
            modules = [
              inputs.nur.modules.nixos.default
              inputs.nixpkgs-xr.nixosModules.nixpkgs-xr
              {
                home-manager.users.${username}.imports = [
                  ./hosts/hara/home
                  inputs.cosmic-manager.homeManagerModules.cosmic-manager
                  inputs.betterfox-nix.homeModules.betterfox
                ];
              }
            ];
          };

          myputer = {
            path = ./hosts/myputer;
            arch = "x86_64";
            class = "darwin";
            nixpkgs = inputs.nixpkgs-darwin;
          };
        };
      };
    });
}
