{
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    # x86_64-darwin pin: unstable dropped the platform, 26.05 keeps it until end of 2026
    nixpkgs-darwin.url = "github:nixos/nixpkgs?ref=nixpkgs-26.05-darwin";
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
      # release branch matching the nixpkgs-darwin pin; nix-darwin asserts they agree
      url = "github:nix-darwin/nix-darwin?ref=nix-darwin-26.05";
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
    # x86_64-darwin pin: later revs drop the platform and the overlay indexes
    # systemPlatform.${system} unguarded
    nix-vscode-extensions-darwin = {
      url = "github:nix-community/nix-vscode-extensions?rev=1c7bb95446387973178363916a51b14515fa5ee4";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
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
    zsh-patina = {
      url = "github:michel-kraemer/zsh-patina";
      # only used on 26.05-darwin, which lacks zsh-patina. unstable errors on x86_64-darwin
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    yazi = {
      url = "github:sxyazi/yazi";
      # no nixpkgs.follows: yazi.cachix.org is built against yazi's own pinned
      # nixpkgs, following ours changes the derivation hash and misses the cache
    };
    nix-yazi-plugins = {
      url = "github:lordkekz/nix-yazi-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
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
      # darwin pin: the devshell pulls colmena on x86_64-darwin. the CLI and makeHive
      # (flake/colmena.nix) must come from one input, so it isn't split per platform
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";

    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tetra-nurpkgs.url = "github:tetra-fox/nurpkgs";

    ableton-linux.url = "github:shibco/ableton-linux";

    nixcord = {
      url = "github:4evy/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nowplaying = {
      url = "github:tetra-fox/nowplaying";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # upstream's eachDefaultSystem evals x86_64-darwin and fires the 26.05 deprecation warning
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
      serverUsername = "admin";
      # signingKey is the 1password ssh signing key, not shared/keyring/tetra.pub
      identity = {
        name = username;
        email = "me@tetra.cool";
        signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHseoQ278Qrc45S8MUE8vwXnmdxd8OiWXViK0yHYYELz";
      };

      # each overlays/ file is `inputs: final: prev: {...}`
      localOverlays = map (p: import p inputs) (lib.attrValues (inputs.haumea.lib.load {
        src = ./overlays;
        loader = inputs.haumea.lib.loaders.path;
      }));

      # the site tag uses the discovery engine's prefix rule, so the two can't disagree
      sitePrefix = import ./lib/site-prefix.nix {inherit lib;};
      serverHost = name: extra: {
        path = ./hosts + "/${name}";
        arch = "x86_64";
        class = "nixos";
        tags = [(sitePrefix name)];
        specialArgs = {username = serverUsername;};
        modules = [inputs.disko.nixosModules.disko] ++ extra;
      };
      serverHosts = names: extras: lib.genAttrs names (n: serverHost n (extras.${n} or []));

      # also feeds fleetSites, which the ssh client turns into per-site Host blocks
      serverNames = [
        "mesa-svc-01"
        "mesa-svc-02"
        "mesa-store-01"
        "mesa-db-01"
        "mesa-db-02"
        "mesa-db-03"
        "mesa-auth-01"
        "mesa-mon-01"
        "mesa-edge-01"
        "mesa-edge-02"
        "mesa-dns-01"
        "mesa-dns-02"
        "fairlane-store-01"
        "fairlane-db-01"
        "fairlane-svc-01"
        "fairlane-mon-01"
        "fairlane-edge-01"
        "fairlane-edge-02"
        "fairlane-dns-01"
        "fairlane-dns-02"
      ];

      commonSpecialArgs = {
        inherit username serverUsername identity;
        fleetSites = lib.unique (map sitePrefix serverNames);
        modules = inputs.haumea.lib.load {
          src = ./modules;
          loader = inputs.haumea.lib.loaders.path;
        };
        # plain `{lib}: ...` functions, not modules
        fleet = inputs.haumea.lib.load {
          src = ./lib;
          loader = inputs.haumea.lib.loaders.path;
        };
        caps = import ./lib/caps.nix;
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
        system,
        ...
      }: {
        # flake-parts defaults pkgs to inputs.nixpkgs, which throws on x86_64-darwin
        _module.args.pkgs =
          if system == "x86_64-darwin"
          then inputs.nixpkgs-darwin.legacyPackages.${system}
          else inputs.nixpkgs.legacyPackages.${system};

        formatter = pkgs.alejandra;

        # vm tests need kvm
        checks = lib.mkIf (system == "x86_64-linux") (import ./tests {
          inherit pkgs;
          inherit (commonSpecialArgs) modules fleet caps;
        });
        # not inputs': nurpkgs has no x86_64-darwin output and the throwing accessor
        # breaks every `nix <cmd> .#...` on the mac
        packages = inputs.tetra-nurpkgs.packages.${system} or {};

        devShells.default = pkgs.mkShell {
          packages = [
            inputs'.colmena.packages.colmena
            pkgs.nixos-anywhere
            pkgs.sops
            pkgs.age
            pkgs.ssh-to-age
            # ci pulls these via --inputs-from (ci.yml)
            pkgs.just
            pkgs.statix
            pkgs.deadnix
            pkgs.alejandra
          ];
        };
      };

      flake = {
        topology = import ./flake/topology.nix {inherit lib inputs;};
        inherit (import ./flake/colmena.nix {inherit lib inputs;}) colmena colmenaHive;
      };

      easy-hosts = {
        perTag = tag: {
          # no pathExists guard: a tag without a facts file should fail eval
          modules = [(./modules/sites + "/${tag}.nix")];
        };

        shared = {
          specialArgs = commonSpecialArgs;
          modules = [
            # not commonSpecialArgs, so `self` doesn't leak into home-manager
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
                # modules can't reach `inputs` to import sops themselves
                inputs.sops-nix.nixosModules.sops
                ./modules/sites/_options.nix
                # provides the `topo` module arg
                ./modules/sites/_topology.nix
                ./modules/sites/_route-firewall.nix
                # vpnNamespaces option for arr-stack; inert without a namespace
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
          }) ({
            hara = {
              path = ./hosts/hara;
              arch = "x86_64";
              class = "nixos";
              modules = [
                inputs.nixpkgs-xr.nixosModules.nixpkgs-xr
                inputs.stylix.nixosModules.stylix
                {
                  home-manager.users.${username}.imports = [
                    ./hosts/hara/home
                    inputs.zen-browser.homeModules.beta
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
                {home-manager.users.${username}.imports = [./hosts/myputer/home];}
              ];
            };
          }
          // serverHosts serverNames {
            mesa-svc-01 = [inputs.nowplaying.nixosModules.default];
          });
      };
    });
}
