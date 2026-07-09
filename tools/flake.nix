{
  description = "dev/CI tools for my fwake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    alejandra = {
      url = "github:kamadorueda/alejandra";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      perSystem = {
        inputs',
        pkgs,
        ...
      }: {
        packages = {
          inherit (pkgs) just statix;
          alejandra = inputs'.alejandra.packages.default;
          default = pkgs.symlinkJoin {
            name = "nix-config-tools";
            paths = [pkgs.just pkgs.statix inputs'.alejandra.packages.default];
          };
        };
      };
    };
}
