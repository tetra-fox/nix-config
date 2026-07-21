# provides this host's fleet topology attrset as the `topo` module arg, so consumers read
# topo.<derive> instead of each re-importing fleet.topology with the same three arguments. lazy:
# a host that never reads topo never runs the engine. nixos-only -- it needs nixosConfigurations,
# which the darwin eval doesn't carry.
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
