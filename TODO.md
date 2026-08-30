# TODO

## workstations

- openrgb revival: shelved, one reboot-check from done
  - remaining: two warm reboots checking systemd-analyze firmware time (~12s ok / ~40s+ = index dp bus wedged), then uncomment the two imports in hosts/hara/{default.nix,home/default.nix}, rebuild, reboot with acpi_enforce_resources=lax, verify ene dram + suspend hook
  - k100 detector permanently disabled (crashes the keyboard), ckb-next drives it instead

- vrcx vr overlay: blocked upstream on xrizer (no overlay-only support), nothing to do until it ships or i switch to opencomposite per-app

- replace hyprshutdown with our quickshell. hyprshutdown is uggy and gwoss and we can make it pwetty and nice :3

## servers

- authentik/LDAP auth for samba shares
  - really fucking finicky i cant get it to work... someday though.
  - per user exposed shares maybe one per person in the household
  - separate datasets? eg: `megamax/store/tetra` `megamax/store/mel` `megamax/backup/timemachine/tetra` etc etc.
  - when this lands we can update timemachine with auth n stuff.
  - BUT ALSO...... <https://docs.goauthentik.io/endpoint-devices/> maybe?

- fairlane-mon-01: HA has no node exporter yet, so it isn't scraped. mesa points its
  node-haos job at lab.appliances.haosIp; do the same here once the addon is installed

- more alerts: db tier internals. etcd needs listen-metrics-urls on a separate port, and
  patroni's rest api is unauthed incl switchover -- think before opening either to mon
- loki-based alert rules need a per-rule datasource field in mkRule first

- move alert rules from grafana to prometheus, keep grafana as the window. NOT WORTH IT YET
  at 7 rules, revisit when the count grows or when a rule needs a condition gt/lt can't express
  - why: grafana copies the provisioning file into its own db, so removing a rule from config
    doesn't remove it. that's what retiredAlerts is, a tombstone list you add a name to and
    then later have to take back out. `prune = true` solves this for datasources, but the
    option doesn't exist for alert rules
  - prometheus reads rule files live, so deleting the lines deletes the rule. also kills the
    gt/lt condition enum (comparisons become plain promql, so >=, ==, and ranges work),
    mkRule's A-reduce-C pipeline, and the sha256 uid hashing
  - keep the grafana UI: alertmanager as a grafana datasource gives back the firing list and
    the silence button, and the prometheus datasource surfaces the rules read-only (vanilla
    prom has no ruler write api, which is what we want since nix owns them)
  - cost: alertmanager becomes a new unit + routing tree, telegram moves to its bot_token_file
  - verify grafana's alertmanager-datasource option names before building this, don't trust memory

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
