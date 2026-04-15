# ❄️ nix-config

## 🌟 features

"features" are programs and/or their `home-manager` configuration

features are automatically discovered in `features` by [a helper](lib/default.nix#L42-L61)

features will contain one or both of `system.nix` and `home.nix`

`system.nix` contains nixos specific configuration, for example, enabling zsh as a login shell

`home.nix` contains `home-manager` relevant configuration, for example, zsh aliases

features can be enabled by importing `features.<name>.[system|home]` to the corresponding configuration file; the `system` module goes in `hosts/<hostname>/default.nix` and the `home` module goes in `hosts/<hostname>/home/default.nix`.

## 🔧 quirks

"quirks" are machine-specific configuration that doesn't belong in a feature

quirks live in `quirks/<hostname>/` and are passed to the host as a `quirks` specialArg by [a helper](lib/default.nix#L89-L91)

the host imports `quirks` directly in its `default.nix`, which resolves to `quirks/<hostname>/default.nix` and pulls in whatever machine-specific modules are needed

typical quirks include hardware configuration, drive mounts, peripheral workarounds, and other one-off system details that are unique to a specific machine

## 📦 pkgs

every `.nix` file in `pkgs/` is automatically added to the package set as `pkgs.<filename>` via [an overlay](lib/default.nix#L25-L40)

packages are called with `callPackage`, so they follow the standard nixpkgs derivation convention
