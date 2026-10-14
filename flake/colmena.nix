# colmena hive built from the easy-hosts nixos configs
{
  lib,
  inputs,
}: let
  sitePrefix = import ../lib/site-prefix.nix {inherit lib;};

  cfgs = inputs.self.nixosConfigurations;
  deployable = lib.filterAttrs (_: c: (c.config.lab.site.hostIp or null) != null) cfgs;

  mkNode = name: c: {
    deployment = {
      targetHost = c.config.lab.site.hostIp;
      targetUser = c._module.specialArgs.username;
      tags = [(sitePrefix name)];
      # the default, stated because targets are too small to build (edges are 1 core / 900M).
      # the deploy host must build x86_64-linux, see modules/platform/nix/darwin.nix
      buildOnTarget = false;
    };
    imports = c._module.args.modules or [];
  };

  colmena =
    {
      meta = {
        nixpkgs = import inputs.nixpkgs {system = "x86_64-linux";};
        nodeSpecialArgs = lib.mapAttrs (_: c: c._module.specialArgs) deployable;
        nodeNixpkgs = lib.mapAttrs (_: c: c.pkgs) deployable;
      };
    }
    // lib.mapAttrs mkNode deployable;
in {
  inherit colmena;
  colmenaHive = inputs.colmena.lib.makeHive colmena;
}
