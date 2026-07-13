# the monitoring SERVER half (prometheus/grafana/loki). the agent half is in the server profile.
# no authentik at fairlane, so grafana keeps its own login (no OAuth, unlike mesa). unifi
# (unpoller) is skipped for now -- add modules.services.monitoring.unifi + the fairlane
# controller creds later if you want UniFi metrics here.
_: {
  lab.monitoring.server.enable = true;
  # grafana root_url is derived from lab.site.domain in modules/services/monitoring/system.nix
}
