# ❄️ nix-config

my needlessly complex nix(os) configuration

## 🧩 modules

programs and/or their `home-manager` configuration, auto-discovered from `modules/` by haumea and exposed as `modules.<name>.<file>`

each module contains `system.nix`, `home.nix`, or both; modules that behave differently on nix-darwin add a `darwin.nix` face (e.g. `modules.platform.nix.darwin`) sharing the platform-agnostic parts via a `common.nix`

files and directories prefixed with `_` are treated as internal (haumea convention)

### 🗂️ profiles

`modules/profiles/` holds opinionated bundles that compose individual modules into ready-to-use roles:

- `base` — universal baseline imported by every host (nix, sshd, zsh, systemd-boot, etc.); its `darwin.nix` face is the same baseline for macs (myputer), minus what macos owns itself (boot, trim) — sshd is macos' own, hardened to fleet policy via an `sshd_config.d` drop-in
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

lives in `quirks/<hostname>/`

> [!NOTE]
> quirks are automatically imported for the matching host - if `quirks/<host>/` exists, `flake.nix` appends it to that host's module list with no per-host wiring

## 🗺️ topology

![main view](images/topology/main.svg)
