# monitoring

prometheus + grafana + node_exporter + systemd_exporter on a single host. scrapes the host itself; consumers add extra targets via `lab.monitoring.extraScrapeConfigs`.

other service modules push scrape jobs directly to `services.prometheus.scrapeConfigs` and grafana.com dashboards onto the `lab.observability.communityDashboards` bus this module consumes. e.g. `modules.docker.system`'s cadvisor, `modules.nvidia.system`'s gpu exporter.

```nix
{ modules, ... }: {
  imports = [modules.monitoring.system];

  lab.monitoring.extraScrapeConfigs = [
    { job_name = "node-otherbox"; static_configs = [{targets = ["10.0.0.5:9100"];}]; }
  ];

  lab.observability.communityDashboards = [
    { id = 1860; revision = 45; sha256 = "sha256-..."; name = "node-exporter-full"; }
  ];

  lab.monitoring.extraDashboardDirs = [./dashboards];   # one-off local JSON
}
```

per-host bits the module deliberately doesn't touch: grafana's `server.root_url`, oauth/SSO config, the matching sops secret for the oauth client.

## options

- `lab.monitoring.extraScrapeConfigs` - extra prometheus scrape jobs (this host's `node-<hn>` and `systemd-<hn>` are added automatically)
- `lab.monitoring.extraDashboardDirs` - extra grafana provisioning dirs for one-off local JSON dashboards
- `lab.observability.communityDashboards` - grafana.com dashboards by `{ id, revision, sha256, name, datasource? }`. fetched at build time, `${DS_PROMETHEUS}` rewritten to the configured datasource, bundled into one provider dir

## gotchas

- prometheus is not firewall-opened; only reachable from localhost + the docker bridge. consumers reach it via grafana or by tunneling
- grafana 26.05+ wants an explicit `security.secret_key`; this module declares the sops secret and wires it via `$__file{...}` so the value doesn't land in the nix store
- community dashboards are sha256-pinned and fetched at build time, not vendored. add a new one with `sha256 = lib.fakeHash` once and copy the real hash from the error
- per-unit ingress/egress byte metrics need `DefaultIPAccounting = true`, set here. otherwise the `systemd_unit_ip_*_bytes` series are all zero
