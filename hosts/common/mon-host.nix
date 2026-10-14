{
  config,
  lib,
  modules,
  ...
}: {
  imports = [modules.profiles.server.system];

  lab.monitoring = {
    server.enable = true;

    # proxmox nodes aren't nix hosts, so they come from the site facts instead of the flake
    extraScrapeConfigs =
      lib.mapAttrsToList (name: ip: {
        job_name = "node-${name}";
        static_configs = [{targets = ["${ip}:9100"];}];
      })
      config.lab.appliances.proxmoxNodes;
  };

  system.stateVersion = "26.11";
}
