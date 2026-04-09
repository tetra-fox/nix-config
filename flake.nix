{
  inputs = {
    # essentials
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
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
  outputs =
    { self, ... }@inputs:
    let
      lib = import ./lib { inherit inputs; };
    in
    {
      formatter = inputs.nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ] (system: inputs.nixpkgs.legacyPackages.${system}.nixfmt-tree);

      nixosConfigurations = {
        hara = lib.mkHost {
          name = "hara";
          system = "x86_64-linux";
          extraHomeModules = [ inputs.cosmic-manager.homeManagerModules.cosmic-manager ];
        };
      };

      darwinConfigurations = {
        myputer = lib.mkHost {
          name = "myputer";
          system = "x86_64-darwin";
        };
      };
    };
}
