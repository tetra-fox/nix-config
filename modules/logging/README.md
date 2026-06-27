# logging

loki + grafana-alloy on a host that already runs `modules.monitoring.system`. alloy
reads the systemd journal and ships every unit's logs to a local loki; loki is added
as a datasource to the grafana that monitoring provisions.

one journal source catches everything. native services log to the journal by
definition, and oci-containers run as `podman-<name>.service` whose conmon output
also lands in the journal. so there is no per-service or per-container config: turn it
on and queries like `{unit="caddy.service"}` or `{unit=~"podman-.*"}` (all containers)
just work in grafana's explore tab.

```nix
{ modules, ... }: {
  imports = [
    modules.monitoring.system
    modules.logging.system
  ];

  lab.logging.enable = true;
}
```

requires `modules.monitoring.system` on the same host (it provides the grafana the loki
datasource attaches to) and a per-host `siteData` module arg (loki state goes under it).

## dashboards

two provisioned dashboards land in grafana under the `extra-0` provider:

- **Logs** (`logs-journal`) - every journal unit. host + unit dropdowns and a free-text
  search box; pick a unit from the dropdown instead of typing a query. a "log volume by
  level" bar panel up top so errors stand out at a glance
- **Container Logs** (`logs-containers`) - same idea, pre-scoped to `unit=~"podman-.*"` so
  the dropdown only lists containers (the *arr stack, jellyfin, etc.)

both select the loki datasource via a `datasource` template variable rather than a
hardcoded uid, since the provisioned datasource gets an auto-assigned uid. edit the JSON
in `dashboards/`; grafana reloads provisioned dashboards every 60s. for one-off poking,
Explore is still faster than touching these.

## the alloy config is a real file

`config.alloy` is plain alloy, no nix interpolation. host and loki port come from the
environment via `sys.env("HOSTNAME")` / `sys.env("LOKI_PORT")`, set on the alloy unit by
`system.nix`. keeping it nix-free means `alloy fmt` and the editor extension lint exactly
what alloy parses. validate locally with:

```sh
alloy fmt modules/logging/config.alloy        # formatting
alloy validate modules/logging/config.alloy   # needs HOSTNAME and LOKI_PORT in env
```

## options

- `lab.logging.enable` - turn on loki + alloy + the loki datasource
- `lab.logging.lokiPort` - loki http port (default 3100, loopback only)

## gotchas

- promtail reached EOL and was removed from nixpkgs; alloy is the vendor-pointed
  successor. the journald-to-loki pipeline is the same shape, written in alloy's config
  language instead of promtail yaml
- loki is loopback only and not firewall-opened; grafana proxies to it. logs are
  per-host, same topology as prometheus self-scraping. centralize later by pointing
  alloy's `loki.write` at a remote loki if you want one pane for the fleet
- `services.loki.dataDir` wants an absolute path (unlike `prometheus.stateDir` which is
  relative to /var/lib), so it takes `siteData` directly, not the stripped prefix
- retention is 31 days (`limits_config.retention_period = "744h"`) with the compactor
  doing the deletes; single host, finite disk
- apps that log to a file inside their container instead of stdout (some *arr apps) won't
  be in the journal; their container stdout still is. add a file-based alloy source if you
  need those specific logs
