# ❄️ nix-config

## 🌟 features

"features" are programs and/or their `home-manager` configuration

features are automatically discovered in `features` by [a helper](lib/default.nix#L32-L50)

features will contain one or both of `system.nix` and `home.nix`

`system.nix` contains nixos specific configuration, for example, enabling zsh as a login shell

`home.nix` contains `home-manager` relevant configuration, for example, zsh aliases

features can be enabled by importing `features.<name>.[system|home]` to the corresponding configuration file; the `system` module goes in `hosts/<hostname>/default.nix` and the `home` module goes in `hosts/<hostname>/home/default.nix`.
