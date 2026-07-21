# host-role boilerplate shared by every site's monitoring box (mesa-mon-01, fairlane-mon-01):
# the site's prometheus/grafana/loki server. per-site deltas (grafana oauth, unifi, extra
# scrape targets) stay in the host's monitoring.nix.
{modules, ...}: {
  imports = [modules.profiles.server.system];

  lab.monitoring.server.enable = true;

  system.stateVersion = "26.11";
}
