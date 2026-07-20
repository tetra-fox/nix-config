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

- grafana: alerting analog to the dashboard/node exporter discovery
  - hosts can set up grafana alerts that get picked up by the main grafana instance at eval time
  - **impawtent for zfs!!!!!! i have old ass disks!!!!!! do it soon!!!!**
  - maybe zfs exporter too to grafana.

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
