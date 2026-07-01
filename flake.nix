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

    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";

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
        # pure helper functions (the fleet discovery engine, the site-prefix), loaded the same
        # way as modules (paths, imported+applied by callers). separate from `modules` because
        # these are plain `{lib}: ...` functions, not NixOS modules -- they don't belong under
        # modules/. exposed as `fleet` so call sites read fleet.engine / fleet.topology.
        fleet = inputs.haumea.lib.load {
          src = ./lib;
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

        devShells.default = pkgs.mkShell {
          packages = [
            inputs'.colmena.packages.colmena
            pkgs.nixos-anywhere
            pkgs.sops
            pkgs.age
            pkgs.ssh-to-age
            inputs'.alejandra.packages.default
          ];
        };

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

      flake = {
        topology = lib.genAttrs ["x86_64-linux"] (system:
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

        # colmena wants two outputs: the raw hive spec as `colmena`, and the evaluated
        # `colmenaHive = colmena.lib.makeHive self.outputs.colmena`.
        colmena = let
          sitePrefix = import ./lib/site-prefix.nix {inherit lib;};

          cfgs = inputs.self.nixosConfigurations;
          deployable = lib.filterAttrs (_: c: (c.config.lab.site.hostIp or null) != null) cfgs;

          mkNode = name: c: {
            deployment = {
              targetHost = c.config.lab.site.hostIp;
              targetUser = "admin";
              tags = [(sitePrefix name)];
              buildOnTarget = false;
            };
            # colmena re-evals each node, so hand it the module set easy-hosts already assembled.
            imports = c._module.args.modules or [];
          };
        in
          {
            meta = {
              nixpkgs = import inputs.nixpkgs {system = "x86_64-linux";};
              nodeSpecialArgs = lib.mapAttrs (_: c: c._module.specialArgs) deployable;
              nodeNixpkgs = lib.mapAttrs (_: c: c.pkgs) deployable;
            };
          }
          // lib.mapAttrs mkNode deployable;

        colmenaHive = inputs.colmena.lib.makeHive inputs.self.outputs.colmena;
      };

      easy-hosts = {
        perTag = tag: {
          modules = lib.optional (builtins.pathExists (./modules/sites + "/${tag}.nix")) (./modules/sites + "/${tag}.nix");
        };

        shared = {
          specialArgs = commonSpecialArgs;
          modules = [
            # via _module.args (NixOS-only), not commonSpecialArgs, so `self` doesn't leak
            # into the home-manager eval.
            {_module.args.nixosConfigurations = inputs.self.nixosConfigurations;}
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
                inputs.tetra-nurpkgs.nixosModules.grafana-dashboards
                # fleet-wide so every nixos host has the `sops` option without a per-host
                # import; modules can't reach `inputs` to pull it in themselves.
                inputs.sops-nix.nixosModules.sops
                # lab.site.* declarations fleet-wide: site-topology + the deploy output read
                # them as a contract regardless of which site a host is in.
                ./modules/site/options.nix
                # fleet-wide so adding arr-stack to a host doesn't silently fail for want of
                # the `vpnNamespaces` option; inert on hosts that declare no namespace.
                inputs.vpn-confinement.nixosModules.default
              ];
              darwin = [inputs.home-manager.darwinModules.home-manager];
            }
            .${
              class
            } or [
            ];
        };

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
            tags = ["mesa"];
            specialArgs = {username = "admin";};
            modules = [
              inputs.disko.nixosModules.disko
              inputs.nowplaying.nixosModules.default
            ];
          };

          fairlane-svc-01 = {
            path = ./hosts/fairlane-svc-01;
            arch = "x86_64";
            class = "nixos";
            specialArgs = {username = "admin";};
            modules = [
              inputs.disko.nixosModules.disko
            ];
          };

          mesa-mon-01 = {
            path = ./hosts/mesa-mon-01;
            arch = "x86_64";
            class = "nixos";
            tags = ["mesa"];
            specialArgs = {username = "admin";};
            modules = [
              inputs.disko.nixosModules.disko
            ];
          };

          mesa-store-01 = {
            path = ./hosts/mesa-store-01;
            arch = "x86_64";
            class = "nixos";
            tags = ["mesa"];
            specialArgs = {username = "admin";};
            modules = [
              inputs.disko.nixosModules.disko
            ];
          };

          mesa-db-01 = {
            path = ./hosts/mesa-db-01;
            arch = "x86_64";
            class = "nixos";
            tags = ["mesa"];
            specialArgs = {username = "admin";};
            modules = [
              inputs.disko.nixosModules.disko
            ];
          };

          mesa-db-02 = {
            path = ./hosts/mesa-db-02;
            arch = "x86_64";
            class = "nixos";
            tags = ["mesa"];
            specialArgs = {username = "admin";};
            modules = [
              inputs.disko.nixosModules.disko
            ];
          };

          mesa-db-03 = {
            path = ./hosts/mesa-db-03;
            arch = "x86_64";
            class = "nixos";
            tags = ["mesa"];
            specialArgs = {username = "admin";};
            modules = [
              inputs.disko.nixosModules.disko
            ];
          };

          mesa-auth-01 = {
            path = ./hosts/mesa-auth-01;
            arch = "x86_64";
            class = "nixos";
            tags = ["mesa"];
            specialArgs = {username = "admin";};
            modules = [
              inputs.disko.nixosModules.disko
            ];
          };

          mesa-edge-01 = {
            path = ./hosts/mesa-edge-01;
            arch = "x86_64";
            class = "nixos";
            tags = ["mesa"];
            specialArgs = {username = "admin";};
            modules = [
              inputs.disko.nixosModules.disko
            ];
          };

          mesa-edge-02 = {
            path = ./hosts/mesa-edge-02;
            arch = "x86_64";
            class = "nixos";
            tags = ["mesa"];
            specialArgs = {username = "admin";};
            modules = [
              inputs.disko.nixosModules.disko
            ];
          };

          mesa-dns-01 = {
            path = ./hosts/mesa-dns-01;
            arch = "x86_64";
            class = "nixos";
            tags = ["mesa"];
            specialArgs = {username = "admin";};
            modules = [
              inputs.disko.nixosModules.disko
            ];
          };

          mesa-dns-02 = {
            path = ./hosts/mesa-dns-02;
            arch = "x86_64";
            class = "nixos";
            tags = ["mesa"];
            specialArgs = {username = "admin";};
            modules = [
              inputs.disko.nixosModules.disko
            ];
          };
        };
      };
    });
}
