# the monitoring SERVER half (prometheus/grafana/loki). the agent half is in the server profile.
# no authentik at fairlane, so grafana keeps its own login (no OAuth, unlike mesa). unifi
# (unpoller) is skipped for now -- add modules.services.monitoring.unifi + the fairlane
# controller creds later if you want UniFi metrics here.
_: {
  lab.monitoring.server.enable = true;

  services.grafana.settings.server.root_url = "https://stats.fairlane.tetra.cool/";
}
