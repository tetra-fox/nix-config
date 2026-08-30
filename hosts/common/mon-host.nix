# host-role boilerplate shared by every site's monitoring box (mesa-mon-01, fairlane-mon-01):
# the site's prometheus/grafana/loki server, plus the scrape targets that follow from the
# site facts. per-site deltas (grafana oauth, unifi, one-off targets) stay in the host's
# monitoring.nix.
{
  config,
  lib,
  modules,
  ...
}: {
  imports = [modules.profiles.server.system];

  lab.monitoring = {
    server.enable = true;

    # every proxmox node the site's facts file declares, scraped under that node's name.
    # the nodes aren't nix hosts, so they can't be discovered from the flake the way the
    # VMs are; adding one to the site facts is enough, no mon host restates an address
    extraScrapeConfigs =
      lib.mapAttrsToList (name: ip: {
        job_name = "node-${name}";
        static_configs = [{targets = ["${ip}:9100"];}];
      })
      config.lab.appliances.proxmoxNodes;
  };

  system.stateVersion = "26.11";
}
