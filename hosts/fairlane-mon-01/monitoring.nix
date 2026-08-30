# per-site monitoring deltas (server.enable comes from mon-host.nix, the agent from the
# server profile). no authentik at fairlane, so grafana keeps its own login rather than
# mesa's OAuth, and its root_url derives from lab.site.domain in
# modules/services/monitoring/system.nix. the non-NixOS scrape targets are still to
# wire up, tracked in TODO.md
{
  config,
  modules,
  ...
}: {
  imports = [modules.services.monitoring.unifi];

  lab.monitoring.unifi = {
    enable = true;
    # the controller is the UDM, the same box as the gateway, same as mesa; both sites
    # are built to the same address plan so this is the site's own router either way
    controllerUrl = "https://${config.lab.net.gateway}";
  };
}
