{modules, ...}: {
  imports = [
    modules.services.monitoring.system
    modules.services.monitoring.unifi
    modules.services.logging.system
  ];

  lab = {
    monitoring.server.enable = true;
    monitoring.unifi.enable = true;

    logging.enable = true;
  };

  # TODO: fairlane's non-NixOS node-exporter targets (HA, proxmox host) via
  # lab.monitoring.extraScrapeConfigs once they exist.

  services.grafana.settings.server.root_url = "https://stats.fairlane.tetra.cool/";
}
