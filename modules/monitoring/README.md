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
declared `lab.site` address (the internal-VLAN IP when it has one, else the server-VLAN
IP). no hand-maintained target list, no DNS dependency. the derivation lives in
`modules/lib/site-topology.nix` (shared with logging, postgres, caddy, arr-stack).
`instance` is labelled with the hostname so grafana legends read names, not ip:port.

## exporter registry

every exporter a host runs (node, systemd, nvidia, cadvisor, ...) registers a
`{name, port}` into `lab.monitoring.exporters` (declared in the options-only
`registry.nix`). the server folds over each site host's registry to build the scrape
jobs -- agents expose exporters, the server discovers them uniformly. a producer module
(e.g. `modules.nvidia.system`) imports `registry.nix`, registers its exporter, and binds
`lab.monitoring.bindAddr` for its listen address -- so it works whether the host is a
server (loopback) or a remote agent (site IP), without depending on the full stack.

## single-host vs multi-host

the bind/firewall machinery is **dormant on a single-host site** and **activates the
moment a site gains a second host** (no flag, derived from the host count):

- single-host (e.g. `fairlane`): everything binds loopback, no firewall holes.
- multi-host (e.g. `mesa` = `mesa-mon-01` server + `mesa-svc-NN` agents):
  - **agent** exporters bind the site IP; `extraInputRules` opens their ports to the
    server only.
  - **server** grafana binds the site IP (so a remote caddy can proxy `stats.<site>`);
    loki binds `0.0.0.0` (so same-box grafana AND remote alloy reach it), firewall-gated;
    `extraInputRules` opens `:3000`/`:3100` to the site's agents only.
  - all source-scoped via nftables, never the whole VLAN.

vendor-specific integrations live in their own modules -- see `modules/monitoring/unifi.nix`
(UniFi), which self-registers via `lab.monitoring.extraScrapeConfigs` and asserts
`server.enable`. external (non-NixOS) targets the derive can't find are added by hand via
`lab.monitoring.extraScrapeConfigs` (e.g. the HA / proxmox-host node-exporters).

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
- `lab.monitoring.exporters` - registry of `{name, port}` an exporter module registers
  into so the server discovers it (declared in `registry.nix`). node/systemd/nvidia/
  cadvisor populate it; you rarely set it directly.
- `lab.monitoring.bindAddr` - read-only, derived: loopback single-host, site IP multi-
  host. exporter modules set their `listenAddress` from this.
- `lab.monitoring.extraScrapeConfigs` - extra prometheus scrape jobs for targets the
  auto-derive can't discover (non-NixOS hosts, external exporters). same-site NixOS hosts
  are scraped automatically.

dashboards are added via `services.grafana-dashboards.community` (grafana.com dashboards
from the `tetra-nurpkgs` package set) -- list-merged across modules.

## gotchas

- agent exporters bind loopback while a site has one host; they bind the site IP (ens18)
  once there's a remote peer to serve, with source-scoped nftables rules opening
  `:9100`/`:9558` to the server only. these `extraInputRules` need the nftables backend
  (silently ignored under iptables); the base profile enables nftables fleet-wide.
- the scrape derivation reads ONLY sibling INPUT attrs (`networking.hostName`,
  `lab.site.{hostIp,internalIp}`, `lab.monitoring.server.enable`). never read a sibling's
  monitoring-derived output (scrapeConfigs/firewall) -- that creates an A<->B eval cycle
  once two servers exist.
- grafana 26.05+ wants an explicit `security.secret_key`; this module declares the sops
  secret and wires it via `$__file{...}` so the value doesn't land in the nix store
- grafana is always reached via caddy (`stats.<site>.tetra.cool`), never directly. on a
  multi-host site the caddy lives on a different box (the svc agent) and proxies across
  to the server's grafana -- the upstream is auto-derived (see `modules/caddy`'s
  `STATS_UPSTREAM`), so the Caddyfile never hardcodes which box runs grafana.
- per-unit ingress/egress byte metrics need `DefaultIPAccounting = true`, set here.
  otherwise the `systemd_unit_ip_*_bytes` series are all zero
- a proxmox VM that's a monitoring server (`<site>-mon-01`) needs `modules.proxmox-vm.system`
  to boot (qemu-guest + virtio initrd) -- not specific to monitoring, but easy to forget
  when scaffolding a fresh mon box
