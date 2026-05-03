# monitoring

prometheus + grafana + node_exporter + systemd_exporter on a single host. scrapes the host itself automatically; consumers add extra targets via `lab.monitoring.extraScrapeConfigs`.

other service modules (e.g. `modules.docker.system`'s cadvisor, `modules.nvidia.system`'s gpu exporter) push their own scrape jobs directly to `services.prometheus.scrapeConfigs`, and grafana.com dashboards onto the `lab.observability.communityDashboards` bus this module consumes.

## usage

```nix
{ modules, ... }: {
  imports = [modules.monitoring.system];

  lab.monitoring.extraScrapeConfigs = [
    { job_name = "node-otherbox"; static_configs = [{targets = ["10.0.0.5:9100"];}]; }
  ];

  # push community dashboards onto the bus (host-scoped)
  lab.observability.communityDashboards = [
    { id = 1860; revision = 45; sha256 = "sha256-..."; name = "node-exporter-full"; }
  ];

  # one-off local JSONs go through extraDashboardDirs instead
  lab.monitoring.extraDashboardDirs = [./dashboards];

  # host-specific bits the module deliberately doesn't touch:
  services.grafana.settings = {
    server.root_url = "https://stats.example.com/";
    "auth.generic_oauth" = { ... };   # SSO config
  };
}
```

## options (`lab.monitoring.*`)

| option | type | default | description |
| --- | --- | --- | --- |
| `extraScrapeConfigs` | `listOf attrs` | `[]` | additional prometheus scrape jobs (this host's `node-<hn>` and `systemd-<hn>` are added automatically) |
| `extraDashboardDirs` | `listOf path` | `[]` | additional grafana provisioning dirs for one-off local dashboard JSONs (community dashboards go via the observability bus instead) |

## options (`lab.observability.*`, contributed via the imported observability module)

| option | type | default | description |
| --- | --- | --- | --- |
| `communityDashboards` | `listOf submodule` | `[]` | grafana.com dashboards by `{ id, revision, sha256, name, datasource? }`. fetched at build time, `${DS_PROMETHEUS}` rewritten to the configured datasource, bundled into a single grafana provider directory |

## provides

- prometheus daemon (state under `siteData/prometheus`); not firewall-opened, only reachable from localhost + docker bridge
- grafana daemon (state under `siteData/grafana`); listens 127.0.0.1:3000
- node_exporter with systemd + processes collectors enabled
- systemd_exporter (port 9558, loopback) with restart-count / fd-size / ip-accounting collectors on
- `systemd.settings.Manager.DefaultIPAccounting = true;` so per-unit ingress/egress byte metrics actually populate
- bundled host-level dashboards on the bus: `node-exporter-full` (1860) and `systemd-exporter` (22872)
- `monitoring/grafana_secret_key` sops secret (with grafana ownership)

## expects

- grafana `root_url` (the public hostname caddy fronts)
- oauth/SSO config (`auth.generic_oauth` + `auth.disable_login_form`)
- the matching sops secret for oauth client credentials
- caddy reverse proxy in front of grafana (if exposing externally)

## design notes

- prometheus is **not** firewall-opened - only reachable from localhost and the docker bridge. consumers reach it via grafana or by tunneling
- grafana 26.05+ requires an explicit `security.secret_key`; the module declares the sops secret and wires it via `$__file{...}` substitution so the value isn't baked into the nix store
- community dashboards are fetched + sha256-pinned at build time rather than vendored as JSON in the repo. add new ones by setting `lab.observability.communityDashboards` from anywhere; run with `sha256 = lib.fakeHash` once and copy the real hash from the build error
