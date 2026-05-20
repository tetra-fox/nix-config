# docker

docker + oci-containers backend, plus the firewall trust rules that let containers reach native host services (e.g. postgres) without exposing those ports to the LAN.

optional sidecars: watchtower (nightly auto-update) and cadvisor (container metrics onto the observability bus).

```nix
{ modules, ... }: {
  imports = [modules.docker.system];
  lab.docker = {
    watchtower.enable = true;   # nightly pull+recreate+prune; usually for servers
    cadvisor.enable = true;     # container metrics for prometheus
  };
}
```

## options

- `watchtower.enable` (default `false`) - nightly pull/recreate/prune for any running container
- `cadvisor.enable` (default `false`) - scrape + dashboard 14282 onto the observability bus
- `cadvisor.port` (default `8081`) - default avoids sabnzbd's 8080

## gotchas

- the firewall trusts `docker0` and `br-*`, so any container can hit native host services. pg_hba and app-layer auth still apply
- cadvisor lives here (not in `monitoring`) because it's a docker-runtime concern; pushing scrape+dashboard onto the observability bus means a workstation can import this without dragging the monitoring stack along
- watchtower runs daily at 11am local time (UTC for servers)
