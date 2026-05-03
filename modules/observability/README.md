# observability

shared options surface for grafana.com community dashboards. tiny options-only module imported by both producers (service modules with their own dashboards) and the consumer (the monitoring module that fetches + provisions them).

declaring the option in a module that producers can import lets a host import e.g. `modules.docker.system` alone and have its `cadvisor` dashboard contribution be a silent no-op (no monitoring module = no consumer = nothing happens).

prometheus scrape jobs do **not** go through here - service modules write directly to `services.prometheus.scrapeConfigs`, which nixpkgs already declares as a free-form list option whether or not prometheus is enabled.

## options (`lab.observability.*`)

| option | type | default | description |
| --- | --- | --- | --- |
| `communityDashboards` | `listOf submodule` | `[]` | grafana.com dashboards as `{ id, revision, sha256, name, datasource? }`. monitoring fetches + sha256-pins them at build time, rewrites `${DS_PROMETHEUS}` to `datasource` (default `"prometheus"`), and bundles them into a single grafana provider |

## usage

producer side (service module pushing a dashboard for the exporter it just configured):

```nix
{ modules, ... }: {
  imports = [modules.observability.system];

  lab.observability.communityDashboards = [
    {
      id = 14282;
      revision = 1;
      sha256 = "sha256-dqhaC4r4rXHCJpASt5y3EZXW00g5fhkQM+MgNcgX1c0=";
      name = "cadvisor";
    }
  ];
}
```

consumer side: lives in `modules.monitoring.system`; reads `config.lab.observability.communityDashboards`, fetches each via `pkgs.fetchurl`, runs sed over `${DS_PROMETHEUS}`, and provisions the resulting directory as a grafana `community` provider.

## design notes

- list option, so contributions from multiple producers merge automatically
- run with `sha256 = lib.fakeHash` once and copy the real hash from the build error
