# caddy

caddy with the cloudflare DNS plugin baked in (for DNS-01 ACME). hosts point `lab.caddy.caddyfile` at their per-site Caddyfile.

## usage

```nix
{ modules, ... }: {
  imports = [modules.caddy.system];

  lab.caddy.caddyfile = ./files/caddy/Caddyfile;
}
```

## options (`lab.caddy.*`)

| option | type | default | description |
|---|---|---|---|
| `caddyfile` | `nullOr path` | `null` | path to a static Caddyfile. when null, caddy uses the auto-generated config from `services.caddy.virtualHosts` etc |

## provides

- `services.caddy.enable` with `dataDir` under `siteData/caddy`
- `services.caddy.package` rebuilt with the `caddy-dns/cloudflare` plugin so DNS-01 ACME works for `*.<host>.tld`
- `net/cf_token` sops secret + `caddy.env` template
- the systemd `EnvironmentFile` wiring so `$CF_TOKEN` is available to caddy at activation
- 80/tcp + 443/tcp in the firewall
- fail2ban with a `caddy-status` jail that bans IPs hitting 401/403/429 too often (1h base, doubling up to 1 week)

## expects

- the actual Caddyfile contents (route definitions, snippets, upstreams)
- the Caddyfile to log access to `/var/log/caddy/access.log` (the `(log)` snippet pattern); fail2ban scans this file
- any host-specific networking (vlan interfaces, etc.)

## design notes

- the cloudflare plugin lives in the rebuilt package, not as a runtime extension. the `hash` pin guards reproducibility - bump the version + hash together
- `$CF_TOKEN` is referenced in the Caddyfile via `{$CF_TOKEN}`. the env file is rendered by sops-nix at activation, so the plaintext token never lands in the nix store
- fail2ban filter regex matches caddy's default JSON log shape (`"remote_ip":"<HOST>".*"status":(401|403|429)`). tune the status codes in `modules/caddy/system.nix` if you want to ban on more 4xx classes
