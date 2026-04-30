# ❄️ nix-config

my needlessly complex nix(os) configuration

## 🧩 modules

programs and/or their `home-manager` configuration, auto-discovered from `modules/` by haumea and exposed as `modules.<name>.<file>`

each module contains `system.nix`, `home.nix`, or both

files and directories prefixed with `_` are treated as internal (haumea convention)

### 🗂️ profiles

`modules/profiles/` holds opinionated bundles that compose individual modules into ready-to-use roles:

- `base` — universal baseline imported by every host (nix, sshd, zsh, systemd-boot, etc.)
- `workstation` — extends `base` with desktop / interactive-use modules (hyprland, fonts, dev tools, ...)
- `server` — extends `base` with headless / unattended-host modules

hosts import a profile rather than wiring up modules individually:

```nix
# hosts/<host>/default.nix
imports = [modules.profiles.workstation.system];
# hosts/<host>/home/default.nix
imports = [modules.profiles.workstation.home];
```

individual modules can still be imported directly (`modules.<name>.[system|home]`) when a host needs something outside the profile's bundle.

## 🛠️ quirks

machine-specific configuration that doesn't fit as a module - hardware config, drive mounts, peripheral workarounds

lives in `quirks/<hostname>/`, passed to the host as a `quirks` specialArg (wired in `flake.nix`)

## 🗺️ topology

![main view](images/topology/main.svg)
