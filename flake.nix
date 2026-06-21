{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    # separate pin for x86_64-darwin
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

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    alejandra = {
      url = "github:kamadorueda/alejandra";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";

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
    yazi = {
      url = "github:sxyazi/yazi";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-yazi-plugins = {
      url = "github:lordkekz/nix-yazi-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";

    nixos-vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      flake = false;
    };

    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tetra-nurpkgs = {
      url = "github:tetra-fox/nurpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixcord = {
      url = "github:FlameFlag/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nowplaying = {
      url = "github:tetra-fox/nowplaying";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # flake = false to skip the upstream flake-utils.eachDefaultSystem which
    # eagerly evaluates x86_64-darwin and fires the 26.05 deprecation warning
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      flake = false;
    };
    nix-secrets.url = "git+ssh://git@github.com/tetra-fox/nix-secrets.git";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} (let
      inherit (inputs.nixpkgs) lib;
      username = "tetra";

      commonSpecialArgs = {
        inherit username;
        modules = inputs.haumea.lib.load {
          src = ./modules;
          loader = inputs.haumea.lib.loaders.path;
        };
        shared = {
          wallpapers = ./shared/wallpapers;
          keyring = ./shared/keyring;
        };
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
        packages = inputs'.tetra-nurpkgs.packages;

        # `nix run .#update-topology` rebuilds images/topology/{main,network}.svg for the README
        apps.update-topology = lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
          type = "app";
          program = "${pkgs.writeShellScript "update-topology" ''
            set -eu
            out=$(nix build --no-link --print-out-paths .#topology.x86_64-linux.config.output)
            mkdir -p images/topology
            install -m 644 "$out"/main.svg     images/topology/main.svg
            install -m 644 "$out"/network.svg  images/topology/network.svg
            echo "wrote images/topology/{main,network}.svg"
          ''}";
        };
      };

      # `nix build .#topology.x86_64-linux.config.output` renders the network diagram
      flake.topology = lib.genAttrs ["x86_64-linux"] (system:
        import inputs.nix-topology {
          pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [inputs.nix-topology.overlays.default];
          };
          modules = [
            ./topology.nix
            {nixosConfigurations = inputs.self.nixosConfigurations;}
          ];
        });

      easy-hosts = {
        shared = {
          specialArgs = commonSpecialArgs;
          modules = [
            {
              nixpkgs.overlays = [
                inputs.nix-vscode-extensions.overlays.default
                inputs.quickshell.overlays.default
                inputs.nix-yazi-plugins.overlays.default
                inputs.tetra-nurpkgs.overlays.default
                (final: _prev: {
                  claude-code = final.callPackage "${inputs.claude-code-nix}/package.nix" {};
                })
                (final: prev: {
                  kdePackages = prev.kdePackages.overrideScope (_kfinal: kprev: {
                    dolphin = prev.symlinkJoin {
                      name = "dolphin-wrapped";
                      paths = [kprev.dolphin kprev.dolphin.dev];
                      nativeBuildInputs = [prev.makeWrapper];
                      postBuild = ''
                        rm $out/bin/dolphin
                        makeWrapper ${kprev.dolphin}/bin/dolphin $out/bin/dolphin \
                          --set XDG_CONFIG_DIRS "${prev.libsForQt5.__internalKF5.kservice}/etc/xdg:$XDG_CONFIG_DIRS" \
                          --run "${kprev.kservice}/bin/kbuildsycoca6 --noincremental ${prev.libsForQt5.__internalKF5.kservice}/etc/xdg/menus/applications.menu"
                      '';
                      passthru = (kprev.dolphin.passthru or {}) // {dev = kprev.dolphin.dev;};
                    };
                  });
                })
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
              nixos = [
                inputs.home-manager.nixosModules.home-manager
                inputs.nix-topology.nixosModules.default
                "${inputs.nixos-vscode-server}/modules/vscode-server"
                inputs.tetra-nurpkgs.nixosModules.grafana-dashboards
              ];
              darwin = [inputs.home-manager.darwinModules.home-manager];
            }
            .${
              class
            } or [
            ];
        };

        # auto-import ./quirks/<name> when the dir exists, so hosts don't have to wire it themselves
        hosts = lib.mapAttrs (name: cfg:
          cfg
          // {
            modules =
              (cfg.modules or [])
              ++ lib.optional (builtins.pathExists (./quirks + "/${name}")) (./quirks + "/${name}");
          }) {
          hara = {
            path = ./hosts/hara;
            arch = "x86_64";
            class = "nixos";
            modules = [
              inputs.nur.modules.nixos.default
              inputs.nixpkgs-xr.nixosModules.nixpkgs-xr
              inputs.stylix.nixosModules.stylix
              {
                home-manager.users.${username}.imports = [
                  ./hosts/hara/home
                  inputs.cosmic-manager.homeManagerModules.cosmic-manager
                  inputs.betterfox-nix.homeModules.betterfox
                  inputs.catppuccin.homeModules.catppuccin
                  inputs.nixcord.homeModules.default
                ];
              }
            ];
          };

          myputer = {
            path = ./hosts/myputer;
            arch = "x86_64";
            class = "darwin";
            nixpkgs = inputs.nixpkgs-darwin;
            modules = [
              {nixpkgs.config.allowDeprecatedx86_64Darwin = true;}
            ];
          };

          mesa-svc-01 = {
            path = ./hosts/mesa-svc-01;
            arch = "x86_64";
            class = "nixos";
            specialArgs = {username = "admin";};
            modules = [
              inputs.sops-nix.nixosModules.sops
              inputs.disko.nixosModules.disko
              inputs.nowplaying.nixosModules.default
              inputs.vpn-confinement.nixosModules.default
            ];
          };
        };
      };
    });
}
