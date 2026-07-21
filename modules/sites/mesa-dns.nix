# mesa-specific resolver facts. the shared resolver behaviour is in modules.services.bind.system,
# and the RPZ blocklists + zone assembly in _dns-common.nix; mesa runs the defaults (v4-only), so
# this is just the imports.
{modules, ...}: {
  imports = [modules.services.bind.system ./_dns-common.nix];
}
