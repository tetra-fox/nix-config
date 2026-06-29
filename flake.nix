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

    # fleet deploy. layered over easy-hosts: the colmenaHive output below reuses the
    # already-built nixosConfigurations + their declared site IPs/tags.
    colmena = {
      url = "github:zhaofengli/colmena";
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

        # `nix develop` for deploys and secret management: colmena to push
        # configs, sops/age/ssh-to-age for the .sops.yaml workflow. sops lives
        # here rather than the global profile since it's only used in this repo.
        # colmena comes from the flake INPUT, not nixpkgs -- nixpkgs ships 0.4.0 (the
        # old evaluator that chokes on the colmenaHive schema); the input matches the
        # makeHive output we expose.
        devShells.default = pkgs.mkShell {
          packages = [
            inputs'.colmena.packages.colmena
            pkgs.sops
            pkgs.age
            pkgs.ssh-to-age
            inputs'.alejandra.packages.default
          ];
        };

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

      # `colmena apply --on @mesa` (parallel fleet deploy). layered over easy-hosts:
      # we don't redefine the hosts, we reuse the already-built nixosConfigurations and
      # attach deployment metadata derived from data they already declare -- the site IP
      # (lab.site.hostIp) and the site prefix (the same helper the monitoring derive uses).
      # only hosts that declare lab.site.hostIp are in the hive (selects the mesa server
      # fleet; skips hara/myputer/fairlane). `nixos-rebuild --target-host` still works too.
      #
      # colmena's CLI wants TWO outputs: the raw hive spec as `colmena`, and the evaluated
      # `colmenaHive = colmena.lib.makeHive self.outputs.colmena` (per its own hint).
      flake.colmena = let
        # sitePrefix: mesa-svc-01 -> mesa (mirrors the monitoring site-topology helper)
        sitePrefix = name: let
          m = builtins.match "(.+)-(svc|mon|store|db|auth|jelly|edge)-[0-9]+" name;
        in
          if m == null
          then name
          else builtins.head m;

        cfgs = inputs.self.nixosConfigurations;
        # only NixOS hosts that declared a site IP (the deployable mesa fleet)
        deployable = lib.filterAttrs (_: c: (c.config.lab.site.hostIp or null) != null) cfgs;

        mkNode = name: c: {
          deployment = {
            targetHost = c.config.lab.site.hostIp;
            targetUser = "admin";
            tags = [(sitePrefix name)];
            buildOnTarget = false; # build on this host, push the closure
          };
          # reuse the exact module set easy-hosts assembled for this host. colmena
          # re-evals nodes via eval-config, so we hand it the host's own imports +
          # specialArgs rather than reconstructing easy-hosts' assembly logic.
          imports = c._module.args.modules or [];
        };
      in
        {
          meta = {
            nixpkgs = import inputs.nixpkgs {system = "x86_64-linux";};
            # each node carries the specialArgs easy-hosts gave it (username, modules,
            # shared, nixosConfigurations, ...) so the reused module set resolves.
            nodeSpecialArgs = lib.mapAttrs (_: c: c._module.specialArgs) deployable;
            nodeNixpkgs = lib.mapAttrs (_: c: c.pkgs) deployable;
          };
        }
        // lib.mapAttrs mkNode deployable;

      flake.colmenaHive = inputs.colmena.lib.makeHive inputs.self.outputs.colmena;

      easy-hosts = {
        # tag a host with its site (e.g. tags = ["mesa"]) to inherit that site's
        # shared facts -- VLAN/gateway/DNS layout, siteData root -- instead of
        # repeating them in every host's default.nix. see modules/sites/.
        perTag = tag: {
          modules = lib.optional (builtins.pathExists (./modules/sites + "/${tag}.nix")) (./modules/sites + "/${tag}.nix");
        };

        shared = {
          specialArgs = commonSpecialArgs;
          modules = [
            # expose the flake's nixosConfigurations to every host module so a host
            # can read sibling hosts' declared config (used by the monitoring module
            # to auto-derive scrape targets from same-site hosts' static IPs). set via
            # _module.args (NixOS-only) rather than commonSpecialArgs so `self` doesn't
            # leak into the home-manager eval.
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
            tags = ["mesa"];
            specialArgs = {username = "admin";};
            modules = [
              inputs.sops-nix.nixosModules.sops
              inputs.disko.nixosModules.disko
              inputs.nowplaying.nixosModules.default
              inputs.vpn-confinement.nixosModules.default
            ];
          };

          fairlane-svc-01 = {
            path = ./hosts/fairlane-svc-01;
            arch = "x86_64";
            class = "nixos";
            specialArgs = {username = "admin";};
            modules = [
              inputs.sops-nix.nixosModules.sops
              inputs.disko.nixosModules.disko
              inputs.vpn-confinement.nixosModules.default
            ];
          };

          mesa-mon-01 = {
            path = ./hosts/mesa-mon-01;
            arch = "x86_64";
            class = "nixos";
            tags = ["mesa"];
            specialArgs = {username = "admin";};
            modules = [
              inputs.sops-nix.nixosModules.sops
              inputs.disko.nixosModules.disko
            ];
          };

          mesa-store-01 = {
            path = ./hosts/mesa-store-01;
            arch = "x86_64";
            class = "nixos";
            tags = ["mesa"];
            specialArgs = {username = "admin";};
            # no sops-nix: store-01 has no per-host secrets (see hosts/mesa-store-01)
            modules = [
              inputs.disko.nixosModules.disko
            ];
          };
        };
      };
    });
}
