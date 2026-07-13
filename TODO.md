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

- service discovery for caddy
  - a host defines its own caddy routes and ports eg: immich.mesa.tetra.cool:interface:port (: is the delimiter, final syntax tbd)
  - maybe we can derive the ip from the interfaces ip, which should be set in the nix config. use the private vm vlan ip
  - a note on the above though: we have some HA services so if keepalived is present or something, get the floating VIP instead.
  - nix generates a Caddyfile entry at eval time, no more drift.

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
