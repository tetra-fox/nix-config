# nixos-only: darwin evals don't carry nixosConfigurations
{
  config,
  fleet,
  nixosConfigurations,
  ...
}: {
  _module.args.topo = fleet.topology {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };
}
