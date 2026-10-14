{
  inputs = {
    # package sets
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    # x86_64-darwin pin: unstable dropped the platform, 26.05 keeps it until end of 2026
    nixpkgs-darwin.url = "github:nixos/nixpkgs?ref=nixpkgs-26.05-darwin";
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
    tetra-nurpkgs.url = "github:tetra-fox/nurpkgs";

    # flake tools
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    haumea = {
      url = "github:nix-community/haumea";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    easy-hosts.url = "github:tgirlcloud/easy-hosts";

    # infra
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      # release branch matching the nixpkgs-darwin pin; nix-darwin asserts they agree
      url = "github:nix-darwin/nix-darwin?ref=nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    colmena = {
      url = "github:zhaofengli/colmena";
      # darwin pin: the devshell pulls colmena on x86_64-darwin. the CLI and makeHive
      # (flake/colmena.nix) must come from one input, so it isn't split per platform
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-secrets.url = "git+ssh://git@github.com/tetra-fox/nix-secrets.git";
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # theming
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";

    # programs
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
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
    ableton-linux.url = "github:shibco/ableton-linux";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} (let
      inherit (inputs.nixpkgs) lib;
      # modules.<category>.<name>.<face> is the path to modules/<category>/<name>/<face>.nix
      modules = inputs.haumea.lib.load {
        src = ./modules;
        loader = inputs.haumea.lib.loaders.path;
      };
      # fleet.<file> is lib/<file>.nix already applied to {lib}
      fleet = inputs.haumea.lib.load {
        src = ./lib;
        inputs = {inherit lib;};
      };
    in {
      imports = [inputs.easy-hosts.flakeModule];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      easy-hosts = import ./flake/hosts.nix {inherit lib inputs fleet modules;};

      flake = {
        topology = import ./flake/topology.nix {inherit lib inputs;};
        inherit (import ./flake/colmena.nix {inherit lib inputs fleet;}) colmena colmenaHive;
      };

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
          inherit pkgs modules fleet;
          inherit (fleet) caps;
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
    });
}
