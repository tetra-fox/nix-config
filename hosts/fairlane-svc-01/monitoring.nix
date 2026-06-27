{
  modules,
  ...
}: {
  imports = [
    modules.monitoring.system
    modules.monitoring.unifi
    modules.logging.system
  ];

  # this host is the fairlane site's monitoring server. only host in the site today,
  # so it scrapes itself; future fairlane-svc-NN agents are auto-discovered.
  lab.monitoring.server.enable = true;
  lab.monitoring.unifi.enable = true; # fairlane has a UniFi network

  # source-scoped peer firewall rules (monitoring module) need the nftables backend
  networking.nftables.enable = true;

  # journald -> loki -> the grafana provisioned above
  lab.logging.enable = true;

  # TODO: fairlane's non-NixOS node-exporter targets (HA, proxmox host) via
  # lab.monitoring.extraScrapeConfigs once they exist.

  services.grafana.settings.server.root_url = "https://stats.fairlane.tetra.cool/";
}
