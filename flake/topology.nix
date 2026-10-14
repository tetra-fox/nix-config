{
  lib,
  inputs,
}:
lib.genAttrs ["x86_64-linux"] (system:
    import inputs.nix-topology {
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [inputs.nix-topology.overlays.default];
      };
      modules = [
        ../topology.nix
        {nixosConfigurations = inputs.self.nixosConfigurations;}
      ];
    })
