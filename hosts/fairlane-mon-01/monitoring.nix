# per-site monitoring deltas (server.enable comes from mon-host.nix, the agent from the
# server profile). no authentik at fairlane, so grafana keeps its own login rather than
# mesa's OAuth, and its root_url derives from lab.site.domain in
# modules/services/monitoring/system.nix. nothing is stated per-host yet; the unifi
# metrics and the non-NixOS scrape targets still to wire up are tracked in TODO.md
_: {
}
