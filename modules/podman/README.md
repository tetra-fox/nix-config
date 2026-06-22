# podman

podman + oci-containers backend, plus the firewall trust rule that lets containers reach native host services (e.g. postgres) without exposing those ports to the LAN. `dockerCompat` aliases the `docker` cli to podman and `dockerSocket` exposes the Docker-API socket for tooling.

optional sidecars: podman-auto-update (nightly pull+recreate) and cadvisor (container metrics onto the observability bus).

```nix
{ modules, ... }: {
  imports = [modules.podman.system];
  lab.podman = {
    autoUpdate.enable = true;   # nightly pull+recreate of labelled containers; usually for servers
    cadvisor.enable = true;     # container metrics for prometheus
  };
}
```

## options

- `autoUpdate.enable` (default `false`) - enables the `podman-auto-update.timer`; the daily run pulls newer images for labelled containers, recreates them, then prunes old images
- `autoUpdate.containerLabels` (read-only) - container modules spread this into their `labels` to opt into auto-update; it carries `io.containers.autoupdate=registry` when `autoUpdate.enable` is set, otherwise nothing. keeping the label here is the single source for the policy
- `cadvisor.enable` (default `false`) - scrape + dashboard onto the observability bus
- `cadvisor.port` (default `8081`) - default avoids sabnzbd's 8080

## gotchas

- the firewall trusts `podman0` (the default network), so any container on it can hit native host services. pg_hba and app-layer auth still apply. containers reach the host via `--add-host=name:host-gateway`; postgres sees the container's source IP in `10.88.0.0/16`, so list that in `allowedCidrs`
- cadvisor lives here (not in `monitoring`) because it's a container-runtime concern; pushing scrape+dashboard onto the observability bus means a workstation can import this without dragging the monitoring stack along
- podman-auto-update runs daily (the timer's `OnCalendar=daily`, randomized up to 15 min); only containers carrying the autoupdate label are touched, so each container module must spread `autoUpdate.containerLabels` into its `labels`
- podman logs to journald by default, so there are no docker-style log rotation settings; the journal's own rotation applies
