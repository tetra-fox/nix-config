{
  inputs = {
    # essentials
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    betterfox-nix = {
      url = "github:HeitorAugustoLN/betterfox-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";
    alejandra = {
      url = "github:kamadorueda/alejandra";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # look & feel
    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";
    catppuccin.url = "github:catppuccin/nix";
    cosmic-manager = {
      url = "github:HeitorAugustoLN/cosmic-manager";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # apps
    elephant.url = "github:abenz1267/elephant";
    walker = {
      url = "github:abenz1267/walker";
      inputs.elephant.follows = "elephant";
    };

    # shell
    zsh-patina = {
      url = "github:michel-kraemer/zsh-patina";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # darwin
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {self, ...} @ inputs: let
    mkHost = import ./lib inputs;
  in {
    formatter = inputs.nixpkgs.lib.genAttrs [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ] (system: inputs.alejandra.packages.${system}.default);

    nixosConfigurations = {
      hara = mkHost {
        name = "hara";
        system = "x86_64-linux";
        extraModules = [
          inputs.nur.modules.nixos.default
          inputs.nixpkgs-xr.nixosModules.nixpkgs-xr
        ];
        extraHomeModules = [
          inputs.cosmic-manager.homeManagerModules.cosmic-manager
          inputs.betterfox-nix.homeModules.betterfox
        ];
      };
    };

    darwinConfigurations = {
      myputer = mkHost {
        name = "myputer";
        system = "x86_64-darwin";
      };
    };
  };
}
