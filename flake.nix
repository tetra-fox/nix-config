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
      # no nixpkgs.follows: yazi.cachix.org is built against yazi's own pinned
      # nixpkgs, following ours changes the derivation hash and misses the cache
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
      # the unix user servers run as; per-host specialArgs reference this so the fact
      # is stated once (rebuild.sh's remote-deploy user is substituted from it too)
      serverUsername = "admin";
      # the operator's identity, shared by every machine the user drives (hara now, the
      # mac later). the signing key is the 1password ssh signing key, a different key
      # from shared/keyring/tetra.pub (fleet shell access).
      identity = {
        name = "tetra";
        email = "me@tetra.cool";
        signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHseoQ278Qrc45S8MUE8vwXnmdxd8OiWXViK0yHYYELz";
      };

      # local overlays live one-per-file in overlays/; each is `inputs: final: prev: {...}`.
      # loaded as paths (like modules/fleet) so we import and apply inputs ourselves rather
      # than relying on haumea's argument injection.
      localOverlays = map (p: import p inputs) (lib.attrValues (inputs.haumea.lib.load {
        src = ./overlays;
        loader = inputs.haumea.lib.loaders.path;
      }));

      # every server VM has the same shape. the tag (which imports the site facts file)
      # derives from the hostname prefix, the same rule the discovery engine groups sites
      # by, so facts-file membership and engine membership can't disagree.
      sitePrefix = import ./lib/site-prefix.nix {inherit lib;};
      serverHost = name: extra: {
        path = ./hosts + "/${name}";
        arch = "x86_64";
        class = "nixos";
        tags = [(sitePrefix name)];
        specialArgs = {username = serverUsername;};
        modules = [inputs.disko.nixosModules.disko] ++ extra;
      };
      serverHosts = names: lib.genAttrs names (n: serverHost n []);

      commonSpecialArgs = {
        inherit username serverUsername identity;
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
        formatter = pkgs.alejandra;
        packages = inputs'.tetra-nurpkgs.packages;

        devShells.default = pkgs.mkShell {
          packages = [
            inputs'.colmena.packages.colmena
            pkgs.nixos-anywhere
            pkgs.sops
            pkgs.age
            pkgs.ssh-to-age
            # fmt/lint/task tools; ci pulls the same three from the flake.lock
            # nixpkgs pin via --inputs-from, without evaluating this flake (see ci.yml)
            pkgs.just
            pkgs.statix
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
          # no pathExists guard: a tag without a site facts file is a config error and
          # should fail loudly at eval, not silently import nothing
          modules = [(./modules/sites + "/${tag}.nix")];
        };

        shared = {
          specialArgs = commonSpecialArgs;
          modules = [
            # via _module.args (NixOS-only), not commonSpecialArgs, so `self` doesn't leak
            # into the home-manager eval.
            {_module.args.nixosConfigurations = inputs.self.nixosConfigurations;}
            {
              nixpkgs.overlays =
                [
                  inputs.nix-vscode-extensions.overlays.default
                  inputs.quickshell.overlays.default
                  inputs.nix-yazi-plugins.overlays.default
                  inputs.tetra-nurpkgs.overlays.default
                ]
                ++ localOverlays;
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
                ./modules/sites/_options.nix
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
          }) ({
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
          }
          // serverHosts [
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
          ]
          // {
            # the one server with an extra module (nowplaying)
            mesa-svc-01 = serverHost "mesa-svc-01" [inputs.nowplaying.nixosModules.default];
          });
      };
    });
}
