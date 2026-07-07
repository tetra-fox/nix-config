# the colmena hive, derived from the nixos configs easy-hosts already built. colmena wants two
# outputs: the raw hive spec as `colmena`, and the evaluated `colmenaHive`.
#
# only hosts that declare lab.site.hostIp are deployable (the desktop/darwin hosts have no
# deploy target). each node reuses the module set easy-hosts assembled rather than re-deriving
# it, since colmena re-evaluates every node.
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
      targetUser = "admin";
      tags = [(sitePrefix name)];
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
