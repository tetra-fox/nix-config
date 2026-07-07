# caddy

caddy + the cloudflare DNS plugin baked into the package (for DNS-01 ACME on `*.<host>.tld`). hosts point `lab.caddy.caddyfile` at their per-site Caddyfile.

```nix
{ modules, ... }: {
  imports = [modules.services.caddy.system];
  lab.caddy.caddyfile = ./files/caddy/Caddyfile;
}
```

`$CF_TOKEN` is wired in via sops; reference it in the Caddyfile as `{$CF_TOKEN}`. LAN/loopback/RFC1918 are in `ignoreIP`.

two fail2ban jails run against `/var/log/caddy/access.log`:

- `caddy-status` (`files/caddy-status.conf`): bans IPs that hit 401/403/429 too often (5 in 10m, 1h base ban doubling up to 1 week). auth/rate abuse.
- `caddy-probe` (`files/caddy-probe.conf`): instabans (maxretry=1, 24h base) any request whose PATH matches a known vulnerability-scanner probe (`.php`, `/.env`, `/.git/`, wordpress paths, phpunit, shells). matches on the path, not the status, so it also catches probes that get a 200/302 (a scanner path caddy proxied to a real backend). the `.php` catch-all is safe because nothing behind this caddy serves php.

## curating the probe list

`caddy-probe.conf` is seeded from our own access logs, not a public feed, and extended by hand. to find new probe paths to add, ssh to the current edge VIP holder and rank the suspicious paths:

```sh
LOG=/var/log/caddy/access.log
# top request paths, app noise + our own service APIs stripped, most-hit first
grep -oE '"(GET|POST|HEAD|PUT) [^"]*"' "$LOG" \
  | sed -E 's/"[A-Z]+ ([^ ?]*)[^"]*"/\1/' \
  | grep -vE '^/(frontend_latest|api|hacsfiles|Items|Shows|Users|Sessions|Plugins|System|Library|Branding|socket|web/)' \
  | grep -vE '\.(js|css|map|png|jpe?g|svg|woff2?|ico|json|webp|gif)$' \
  | sort | uniq -c | sort -rn | head -50
```

the exclude list is our real services (home assistant frontend, jellyfin's `/Items` `/Shows` `/Users` etc); anything left near the top that we don't serve is a probe candidate. add the distinctive path fragment to `probe_paths`, escaping every literal dot. do NOT add bare `/login`, `/admin`, `/api`, `/wp-json` (without the specific plugin) or anything a real service could serve.

## gotchas

- the cloudflare plugin is baked into the package (`pkgs.caddy.withPlugins`), not loaded at runtime. the `hash` pin needs bumping together with the version
- both filters match apache-style common_log (caddy's `transform-encoder` plugin, baked into the package). `caddy-status` deliberately skips 404 and other 4xx so a reverse-proxied SPA's missing source maps and favicons don't false-positive; `caddy-probe` bans on the path regardless of status. `caddy-probe` anchors its match to the request path (stops at `?`), so a probe path reflected into a legit `/login?redirectTo=...` query does not trip it
- the Caddyfile is expected to log access to `/var/log/caddy/access.log` (use the `(log)` snippet)
