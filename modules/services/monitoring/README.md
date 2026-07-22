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
`lib/topology.nix` (shared with logging, postgres, caddy, arr-stack).
`instance` is labelled with the hostname so grafana legends read names, not ip:port.

## exporter registry

every exporter a host runs (node, systemd, nvidia, zfs, cadvisor, ...) registers a
`{name, port}` into `lab.monitoring.exporters` (declared in the options-only
`registry.nix`). the server folds over each site host's registry to build the scrape
jobs -- agents expose exporters, the server discovers them uniformly. a producer module
(e.g. `modules.hardware.nvidia.system`, `modules.platform.zfs.system`) imports `registry.nix`,
registers its exporter, and binds `lab.monitoring.bindAddr` for its listen address -- so it
works whether the host is a server (loopback) or a remote agent (site IP), without
depending on the full stack.

## dashboard + alert registry

the same discovery works for what the server should *show* and *watch*. a producer
registers alongside its exporter:

- `lab.monitoring.dashboards` -- `pkgs.grafana-dashboards.*` packages. the server folds
  every site host's list (deduped by store path) into its grafana community provider, so
  the zfs dashboard lands on `stats.mesa` because `mesa-store-01` runs zfs, not because
  the mon host lists it.
- `lab.monitoring.alerts` -- compact rule specs the server renders into one
  file-provisioned grafana rule group (folder `fleet`, evaluated every 60s). a rule is
  `{name, expr, condition?, for?, summary, labels?, noDataState?}`: `expr` is an instant
  promql query, `condition` a threshold on its value (default `gt 0`), and one alert
  instance fires per breaching series. use `== bool` comparisons to turn a state into
  0/1 (see `up == bool 0` in the agent block). summaries are go-templated;
  `{{ $values.B }}` is the measured value, `{{ $labels.* }}` come from the series.

identical registrations from many hosts collapse to one rule (the node/systemd baseline
alerts are registered by every agent); the same name with a *different* body is an eval
error. rule uids are hashed from the name, so a rename is a new rule -- and grafana never
deletes provisioned rules on its own, so retiring or renaming one means putting the old
name in `lab.monitoring.retiredAlerts` on the server host until every grafana has dropped it.

there is no contact point provisioned yet: firing alerts show in grafana's alert list
(and annotate dashboards), but push notifications need a per-site
`services.grafana.provision.alerting.contactPoints` + `policies` on the mon host.

## blackbox probes

`blackbox.nix` rides along with the server role and probes what users actually hit,
not per-box health: https through the edge for every vhost in the site's route
registry (the probe list maintains itself), a dns query against the resolver
endpoint (`topo.dnsEndpointIp`, the bind VIP), and a tcp connect to the db endpoint
(`topo.dbEndpointIp`). the exporter binds loopback, only the same-box prometheus
talks to it. comes with `probe failed` and `tls certificate expiring` (<14d) alerts;
the cert one is the tripwire for a silently broken acme renewal.

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
  imports = [modules.services.monitoring.system];

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
- `lab.monitoring.dashboards` - grafana dashboard packages this host wants on its site's
  grafana (see the registry section above).
- `lab.monitoring.alerts` - alert rules this host wants its site's grafana to evaluate.
- `lab.monitoring.retiredAlerts` - names of removed rules grafana should delete (server
  host only).

dashboard packages come from `pkgs.grafana-dashboards` (grafana.com dashboards pinned in
`tetra-nurpkgs`). server-local integrations like unpoller still assign
`services.grafana-dashboards.community` directly -- the registry is for dashboards that
follow a *remote* producer.

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
- grafana is always reached via caddy (`stats.<site>.tetra.cool`), never directly. the
  module declares the stats vhost via `lab.topology.routes`, so the edge renders the
  upstream from the route registry and the Caddyfile never hardcodes which box runs grafana.
- per-unit ingress/egress byte metrics need `DefaultIPAccounting = true`, set here.
  otherwise the `systemd_unit_ip_*_bytes` series are all zero
- file-provisioned alert rules are read-only in the grafana UI, and grafana keeps rules
  that vanish from the provisioning file -- removal goes through `retiredAlerts`
- alert rules default `noDataState = "OK"`: a vanished series usually means the exporter
  died, which the target-down alert already reports; `NoData` would fire both
- a proxmox VM that's a monitoring server (`<site>-mon-01`) needs `modules.platform.proxmox-vm.system`
  to boot (qemu-guest + virtio initrd) -- not specific to monitoring, but easy to forget
  when scaffolding a fresh mon box
