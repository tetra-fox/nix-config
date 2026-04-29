# monitoring

prometheus + grafana + node-exporter + cadvisor on a single host. scrapes the host itself automatically; consumers add extra targets via `lab.monitoring.extraScrapeConfigs`.

## usage

```nix
{ modules, ... }: {
  imports = [modules.monitoring.system];

  lab.monitoring.extraScrapeConfigs = [
    { job_name = "node-otherbox"; static_configs = [{targets = ["10.0.0.5:9100"];}]; }
  ];

  # host-specific bits the module deliberately doesn't touch:
  services.grafana.settings = {
    server.root_url = "https://stats.example.com/";
    "auth.generic_oauth" = { ... };   # SSO config
  };
  services.grafana.provision.dashboards.settings.providers = [
    { name = "homelab"; options.path = ./dashboards; ... }
  ];
}
```

## options (`lab.monitoring.*`)

| option | type | default | description |
|---|---|---|---|
| `extraScrapeConfigs` | `listOf attrs` | `[]` | additional prometheus scrapeConfigs (this host's `node-<hn>` and `cadvisor-<hn>` jobs are added automatically) |

## provides

- prometheus daemon (state under `siteData/prometheus`); not firewall-opened, only reachable from localhost + docker bridge
- grafana daemon (state under `siteData/grafana`); listens 127.0.0.1:3000
- node_exporter with systemd + processes collectors enabled
- cadvisor on port 8081 (avoids sabnzbd's 8080)
- `monitoring/grafana_secret_key` sops secret (with grafana ownership)

## expects

- grafana `root_url` (the public hostname caddy fronts)
- oauth/SSO config (`auth.generic_oauth` + `auth.disable_login_form`)
- the matching sops secret for oauth client credentials
- dashboards (`provision.dashboards.settings.providers`)
- caddy reverse proxy in front of grafana (if exposing externally)

## design notes

- prometheus is **not** firewall-opened - only reachable from localhost and the docker bridge. consumers reach it via grafana or by tunneling
- grafana 26.05+ requires an explicit `security.secret_key`; the module declares the sops secret and wires it via `$__file{...}` substitution so the value isn't baked into the nix store
