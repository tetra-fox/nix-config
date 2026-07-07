# the nix-topology output (the network diagram generator), one entry per supported system.
# the topology MODULE that describes the fleet is ../topology.nix; this is just the wiring that
# feeds it nixpkgs + the nixos configs and exposes it as a flake output.
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
