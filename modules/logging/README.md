# logging

follows the monitoring module's server/agent split:

- **agent** (`lab.logging.enable = true`, any host): grafana-alloy reads the systemd
  journal (+ optional file sources) and ships logs to its site's loki.
- **server** (the host with `lab.monitoring.server.enable`): runs loki, adds it as a
  grafana datasource, and ships the log dashboards.

an agent finds its site's loki by the same `site-topology.nix` derivation the monitoring
module uses: alloy's `loki.write` endpoint (`LOKI_HOST`) is `127.0.0.1` on the server
(loki is local) and the site server's derived IP on a remote agent. exactly one server
per site is asserted.

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

  lab.logging.enable = true;            # this host ships its logs
  # loki itself only comes up where lab.monitoring.server.enable is set.
}
```

a single-host site (e.g. `fairlane`) ships to its own loopback loki. a multi-host site
(e.g. `mesa`: `mesa-svc-NN` agents + `mesa-mon-01` server) has the agents ship to the
server's loki over the network -- the agent's `LOKI_HOST` derives the server's IP, the
server's loki binds `0.0.0.0` (firewall-gated to the site's agents by the monitoring
module), and same-box grafana still reaches it on loopback. needs a per-host `siteData`
module arg (loki state goes under it).

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

`config.alloy` is plain alloy, no nix interpolation. hostname and the loki endpoint come
from the environment via `sys.env("HOSTNAME")` / `sys.env("LOKI_HOST")` /
`sys.env("LOKI_PORT")`, set on the alloy unit by `system.nix` (`LOKI_HOST` is loopback on
the server, the derived server IP on an agent). keeping it nix-free means `alloy fmt` and
the editor extension lint exactly what alloy parses. validate locally with:

```sh
alloy fmt modules/logging/config.alloy        # formatting
alloy validate modules/logging/config.alloy   # needs HOSTNAME, LOKI_HOST, LOKI_PORT in env
```

## options

- `lab.logging.enable` - this host ships its logs (alloy). loki itself only comes up on
  the host with `lab.monitoring.server.enable`.
- `lab.logging.lokiPort` - loki http port (default 3100)

## gotchas

- promtail reached EOL and was removed from nixpkgs; alloy is the vendor-pointed
  successor. the journald-to-loki pipeline is the same shape, written in alloy's config
  language instead of promtail yaml
- loki binds loopback single-host, `0.0.0.0` multi-host (gated to the site's agents by
  the monitoring module's source-scoped nftables rule -- needs
  `networking.nftables.enable = true`). same-box grafana queries it on loopback either way
- `services.loki.dataDir` wants an absolute path (unlike `prometheus.stateDir` which is
  relative to /var/lib), so it takes `siteData` directly, not the stripped prefix
- retention is 31 days (`limits_config.retention_period = "744h"`) with the compactor
  doing the deletes; finite disk on the mon box
- apps that log to a file inside their container instead of stdout (some *arr apps) won't
  be in the journal; their container stdout still is. add a file-based alloy source if you
  need those specific logs
