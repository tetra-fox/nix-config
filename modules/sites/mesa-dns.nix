# mesa-specific resolver facts. the shared resolver behaviour is in modules.services.bind.system,
# and the RPZ blocklists + zone assembly in _dns-common.nix; mesa runs the defaults (v4-only).
{
  config,
  modules,
  ...
}: {
  imports = [modules.services.bind.system ./_dns-common.nix];

  # the UDM's web ui, the one appliance name that must resolve off the wildcard
  lab.bind.zone.extraRecords = "unifi IN A ${config.lab.net.gateway}";
}
