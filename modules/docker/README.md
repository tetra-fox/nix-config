# docker

docker daemon + oci-containers backend + a watchtower auto-update sidecar. plus the firewall trust rules that let containers reach native services on the host (e.g. postgres) without opening ports to the LAN.

## usage

```nix
{ modules, ... }: {
  imports = [modules.docker.system];

  lab.docker.watchtower.enable = true;   # nightly auto-update; usually wanted on servers, not workstations
}
```

## options (`lab.docker.*`)

| option | type | default | description |
| --- | --- | --- | --- |
| `watchtower.enable` | bool | `false` | run watchtower in a container (nightly pull + recreate + prune for any running container) |

## provides

- `virtualisation.docker.enable = true` with overlay2 + JSON file logging (10MB max, 3 files), weekly auto-prune
- `virtualisation.oci-containers.backend = "docker"` so other modules can declare `virtualisation.oci-containers.containers.foo = {...}`
- `users.users.<username>.extraGroups += ["docker"]` for the primary user
- firewall trust for `docker0` + `br-*` interfaces so containers reach native host services (postgres, etc.) without LAN exposure
- the watchtower container itself (when `watchtower.enable`)

## expects

- the actual containers (`virtualisation.oci-containers.containers.<x>`)
- whether watchtower runs (default off; flip on per-host where appropriate)

## design notes

- trusting docker bridge interfaces is the alternative to listening on `127.0.0.1` only and adding port mappings. simpler than the listen-address fiddling for many services that just want any-bridge access. pg_hba and equivalent application-layer auth still enforce
