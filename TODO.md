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

- caddy route inversion (was: "service discovery for caddy")
  - the engine half is already done: ipOf derives the internal-vlan IP (lib/engine.nix, prefers
    internalIp), endpointFor+vipPath is the keepalived-VIP seam. don't rebuild either. the old
    :-delimited string syntax idea is dropped (unparseable, unvalidated) in favor of an attrset.
  - the one real item: invert who owns the routes. today caddy's Caddyfile is a hand-written
    static asset (hosts/*/files/caddy/Caddyfile) with six env-var upstream holes; adding a service
    means editing caddy. want: a host publishes lab.topology.routes = [{host, port, <policy>}],
    caddy folds over the site collecting routes, resolves each publisher's address with ipOf (VIP
    seam where HA), and renders the Caddyfile. adding a service then touches only that module.
  - constraints: route submodule is a plain input (or readOnly+static default like arrDatabases)
    or the fold cycles. a route carries NO ip (publisher declares what, engine resolves where).
    policy modifiers that recur are typed options (lanOnly, maxBodySize, scheme, tlsInsecure).
    one vhost per route, no comma-grouping (human ergonomics for a file no human reads now).
  - appliances with no publisher (home.mesa -> HAOS 192.168.10.5, pve.mesa -> proxmox) stay in a
    hand-written static tail. do NOT add a literalUpstream escape hatch to the route type -- that
    reintroduces "route carries its own address" as an option and contaminates every route.
  - OPEN: the arr vhosts. on mesa they proxy to authentik's outpost ({$AUTH_UPSTREAM}) via
    forward_auth, NOT to the arr host; on fairlane they proxy the arr UIs directly ({$ARR_HOST}).
    the route type needs to express "upstream is the site auth outpost" but design that
    abstraction against BOTH patterns at once, not just mesa's, or it gets reworked when fairlane
    lands. deferred out of the first slice; arr block stays in the static tail until then.
  - proof slice: mesa-edge-01 only, fairlane untouched. invert the clean reverse-proxy vhosts
    (auth, jellyfin, immich w/ 50GB body, stats, np); static tail holds mesa.tetra.cool root,
    home, pve, the arr block. acceptance test: rendered-vs-current Caddyfile diff empty modulo
    whitespace and vhost ordering. a non-empty diff is a finding (behavior you didn't know you
    had), not a failure.
  - DONE already: engine arity fix. ipWhere now throws on 2+ providers (null only for zero) and
    endpointFor throws on divergent VIPs, so two hosts advertising the same cap fails at eval
    instead of silently resolving to null and dropping the route.

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
  - this is the same goal as the repo being fork-it public, so it's worth doing
