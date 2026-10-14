{
  config,
  modules,
  ...
}: {
  imports = [modules.services.bind.system ./_dns-common.nix];

  # the UDM's web ui, the one appliance name that must resolve off the wildcard
  lab.bind.zone.extraRecords = "unifi IN A ${config.lab.net.gateway}";
}
