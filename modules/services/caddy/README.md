# caddy

caddy + the cloudflare DNS plugin baked into the package (for DNS-01 ACME on `*.<host>.tld`). hosts point `lab.caddy.caddyfile` at their per-site Caddyfile.

```nix
{ modules, ... }: {
  imports = [modules.services.caddy.system];
  lab.caddy.caddyfile = ./files/caddy/Caddyfile;
}
```

`$CF_TOKEN` is wired in via sops; reference it in the Caddyfile as `{$CF_TOKEN}`. fail2ban runs a `caddy-status` jail against `/var/log/caddy/access.log`, banning IPs that hit 401/403/429 too often (1h base, doubling up to 1 week). LAN/loopback/RFC1918 are in `ignoreIP`.

## gotchas

- the cloudflare plugin is baked into the package (`pkgs.caddy.withPlugins`), not loaded at runtime. the `hash` pin needs bumping together with the version
- the fail2ban filter matches apache-style common_log (caddy's `transform-encoder` plugin, baked into the package), failregex `^<HOST>.*"..." (401|403|429)`; it deliberately skips 404 and other 4xx so a reverse-proxied SPA's missing source maps and favicons don't false-positive. tune the status codes in `files/caddy-status.conf` if you want to widen the net
- the Caddyfile is expected to log access to `/var/log/caddy/access.log` (use the `(log)` snippet)
