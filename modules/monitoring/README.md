# monitoring

two roles:

- **agent** (always on, every host that imports this module): node-exporter +
  systemd-exporter. produces metrics about the host. unconditional -- self-observability
  is an invariant, not a toggle.
- **server** (`lab.monitoring.server.enable = true`): prometheus + grafana on top. one
  per site (the `<site>-mon-01` box). auto-discovers and scrapes every agent in its site.

a "site" is the hostname prefix: `mesa-svc-01`, `mesa-svc-02`, `mesa-mon-01` all share
site `mesa`. the server derives its scrape list by folding over the flake's
`nixosConfigurations`, keeping hosts that share its site prefix, and reading each one's
declared static IPv4 (`networking.interfaces.*.ipv4.addresses`). no hand-maintained
target list, no DNS dependency. the derivation lives in `site-topology.nix` (shared with
the logging module). `instance` is labelled with the hostname so grafana legends read
names, not ip:port.

today each site has one host and it's the server, so the derived peer set is just
`[self]`, scraped over loopback. the remote-agent machinery (off-loopback binds,
source-scoped firewall rules) stays dormant until a site gains a second host -- then
exporters bind the site IP and `extraInputRules` opens `:9100`/`:9558` to the server only.

other service modules contribute scrape jobs directly to `services.prometheus.scrapeConfigs`
(e.g. `modules.nvidia.system`'s gpu exporter, the docker cadvisor) and grafana dashboards
onto `services.grafana-dashboards.community`. vendor-specific integrations live in their
own modules -- see `modules/monitoring/unifi.nix` (UniFi), which self-registers via
`lab.monitoring.extraScrapeConfigs` and asserts `server.enable`.

```nix
{ modules, ... }: {
  imports = [modules.monitoring.system];

  # the site's monitoring server (one per site). omit on agent-only hosts.
  lab.monitoring.server.enable = true;

  # extra non-NixOS / external targets the auto-derive can't find (HA, proxmox host, ...)
  lab.monitoring.extraScrapeConfigs = [
    { job_name = "node-otherbox"; static_configs = [{targets = ["10.0.0.5:9100"];}]; }
  ];
}
```

per-host bits the module deliberately doesn't touch: grafana's `server.root_url`,
oauth/SSO config, the matching sops secret for the oauth client.

## options

- `lab.monitoring.server.enable` - make this host the site's monitoring server
  (prometheus + grafana + loki via the logging module). default false. the agent
  exporters run regardless.
- `lab.monitoring.extraScrapeConfigs` - extra prometheus scrape jobs for targets the
  auto-derive can't discover (non-NixOS hosts, external exporters). same-site NixOS hosts
  are scraped automatically.

dashboards are added via `services.grafana-dashboards.community` (grafana.com dashboards
from the `tetra-nurpkgs` package set) -- list-merged across modules.

## gotchas

- agent exporters bind loopback while a site has one host; they bind the site IP (ens18)
  once there's a remote peer to serve, with source-scoped nftables rules opening
  `:9100`/`:9558` to the server only. **requires `networking.nftables.enable = true`** --
  `extraInputRules` is silently ignored under the iptables backend.
- the scrape derivation reads ONLY sibling INPUT attrs (`networking.hostName`,
  `networking.interfaces.*.ipv4.addresses`, `lab.monitoring.server.enable`). never read a
  sibling's monitoring-derived output (scrapeConfigs/firewall) -- that creates an A<->B
  eval cycle once two servers exist.
- grafana 26.05+ wants an explicit `security.secret_key`; this module declares the sops
  secret and wires it via `$__file{...}` so the value doesn't land in the nix store
- prometheus + grafana are loopback only and not firewall-opened; grafana is reached via
  caddy reverse proxy (`stats.<site>.tetra.cool`)
- per-unit ingress/egress byte metrics need `DefaultIPAccounting = true`, set here.
  otherwise the `systemd_unit_ip_*_bytes` series are all zero
