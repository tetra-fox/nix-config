# nixos-only: darwin evals don't carry nixosConfigurations
{
  lib,
  config,
  fleet,
  nixosConfigurations,
  ...
}: {
  _module.args.topo = import fleet.topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };
}
