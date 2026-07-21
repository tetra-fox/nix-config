# per-site monitoring deltas (server.enable comes from mon-host.nix, the agent from the
# server profile). no authentik at fairlane, so grafana keeps its own login (no OAuth,
# unlike mesa). unifi (unpoller) is skipped for now -- add modules.services.monitoring.unifi
# + the fairlane controller creds later if you want UniFi metrics here.
_: {
  # grafana root_url is derived from lab.site.domain in modules/services/monitoring/system.nix

  # TODO: fairlane's non-NixOS node-exporter targets (HA, proxmox hosts) via
  # lab.monitoring.extraScrapeConfigs once they exist.
}
