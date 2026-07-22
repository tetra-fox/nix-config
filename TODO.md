# TODO

## workstations

- openrgb revival: shelved, one reboot-check from done
  - remaining: two warm reboots checking systemd-analyze firmware time (~12s ok / ~40s+ = index dp bus wedged), then uncomment the two imports in hosts/hara/{default.nix,home/default.nix}, rebuild, reboot with acpi_enforce_resources=lax, verify ene dram + suspend hook
  - k100 detector permanently disabled (crashes the keyboard), ckb-next drives it instead

- 1password ssh agent: apply the permanent SSH_AUTH_SOCK fix so i stop doing the manual export
  - `home.sessionVariables.SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";` in modules/ssh/home.nix
  - or just disable gcr-ssh-agent (cosmic doesn't need it): services.gnome.gnome-keyring.enable = lib.mkForce false

- vrcx vr overlay: blocked upstream on xrizer (no overlay-only support), nothing to do until it ships or i switch to opencomposite per-app
- vrcx shutdown hang: needs kill -9 on quit, pre-existing stock nixpkgs bug, diagnose later (CEF subprocess / unreaped wineserver suspects)

- replace hyprshutdown with our quickshell. hyprshutdown is uggy and gwoss and we can make it pwetty and nice :3

## servers

- caddy route inversion: SHIPPED. hosts publish lab.topology.routes = [{host, port, scheme?,
  maxBodySize?}]; the engine folds them per-site (routesInSite) resolving each publisher's
  address via ipOf, and caddy renders the Caddyfile from that plus a per-host staticTail
  (appliances with no publisher: root, home/HAOS, pve). inverted both edge tiers (mesa +
  fairlane); engine covered by lib/fleet-test.nix.
  - STILL OPEN: the arr vhosts. mesa proxies them through authentik's outpost ({$AUTH_UPSTREAM})
    via forward_auth; fairlane proxies the arr UIs directly ({$ARR_HOST}, lan_only). both still
    hand-written in each edge's caddy-tail.nix. inverting them needs a route type that expresses
    "upstream is the site auth outpost" -- design it against BOTH patterns at once or it gets
    reworked when fairlane lands. authUpstream + arrHost options stay until then.

- authentik/LDAP auth for samba shares
  - really fucking finicky i cant get it to work... someday though.
  - per user exposed shares maybe one per person in the household
  - separate datasets? eg: `megamax/store/tetra` `megamax/store/mel` `megamax/backup/timemachine/tetra` etc etc.
  - when this lands we can update timemachine with auth n stuff.

- grafana: alerting analog to the dashboard/node exporter discovery: BUILT. hosts register
  lab.monitoring.{alerts,dashboards} (registry.nix); the site server folds both at eval time
  into a provisioned grafana rule group (folder "fleet") + the community dashboard provider.
  platform/zfs self-registers the pdf zfs_exporter, pool unhealthy/capacity alerts, and the
  zfs dashboard; every agent registers target-down + unit-failed baselines.
  - to land: push nurpkgs (new zfs + smartctl dashboards), bump flake.lock, rebuild
    mesa-mon-01 + mesa-store-01
  - smartctl exporter: DONE. modules/hardware/smartctl (exporter + smart-failed /
    sector-errors / temperature alerts + dashboard), imported by mesa-store-01. SMART
    verified working through the virtio-scsi passthrough (sat auto-detect)
  - contact point: telegram, added by hand in grafana's UI (bot token + chat id stay out
    of the repo; it's ui state in grafana's dataDir, two fields to redo if ever lost).
    check the default notification policy routes to it, or provisioned rules keep going
    to the dead grafana-default-email receiver
  - fleet alert set: baselines from every agent (target down, unit failed, fs >85%,
    oom kills, service flapping, clock unsync) + producer-registered (zfs pool
    health/capacity, smart x3, restic stale, arr vpn down, gpu temp)
  - blackbox: DONE. monitoring/blackbox.nix rides the server role; https probes derived
    from the route registry, dns probe against topo.dnsEndpointIp (caps.dns gained its
    vipPath), tcp to topo.dbEndpointIp. probe-failed + cert-expiry (<14d) alerts
  - NEXT alerts: db tier internals (etcd needs listen-metrics-urls on a separate port
    and patroni's rest api is unauthed incl switchover -- think before opening either
    to mon); loki-based rules need a per-rule datasource field in mkRule first
  - influxdb: rejected. prometheus covers pool health/capacity (pdf zfs_exporter) and
    arc/io (node exporter zfs collector); influx's only real edge is zpool_influxdb's
    per-vdev latency histograms, not worth a second tsdb + telegraf

## general

- full audit of modules: make sure everything is generic and not tied to any of my specific configuration or needlessly intertwined with other modules
  - lots of moving parts that could break and going to be time consuming as fuck
  - if we need to create like a generic interface that our boxes consume we will restruture.
  - ensure clean seams.

- audit service fw rules and generate nftables rules from config
  - dont eagerly listen on all interfaces, just what we need
  - if we can limit to vlan 1010 (10.10.0.0/24) we should for eastwest
  - so update listening interfaces AND fw rules.
  - explicitly leave out the \*arrs. still accessed by ip because authentik's proxy is a little Freaked Up. (might just make the arrs `lan_only` To Be Tbh.)
