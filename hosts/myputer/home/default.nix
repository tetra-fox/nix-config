{
  identity,
  lib,
  modules,
  pkgs,
  ...
}: {
  imports = [
    modules.profiles.base.home

    modules.cli.direnv.home
    modules.cli.fastfetch.home
    modules.cli.ghostty.home
    modules.cli.git.home
    modules.cli.helix.home
    modules.cli.ssh.home
    modules.cli.yazi.home
    modules.desktop.fonts.home
    modules.desktop.vscode.home
  ];

  my = {
    # the operator identity from flake.nix, same as the linux workstations
    git.identity = identity;

    # matches the pre-nix agent.toml this file replaces
    ssh.opVaults = ["Private" "mesa" "fairlane"];
  };

  # the yazi module's flake-input build has no x86_64-darwin cache and would
  # compile the whole crate graph here; the nixpkgs build is on hydra
  programs.yazi.package = lib.mkForce pkgs.yazi;

  # former brew formulae with straight nixpkgs equivalents; what's left in
  # homebrew.brews (hosts/myputer/default.nix) is mac-only or brew-only
  home.packages = with pkgs; [
    # dev toolchains
    nodejs
    pnpm
    rustup
    poetry

    # infra tooling
    ansible
    opentofu
    packer
    influxdb2-cli

    # terminal font with the glyphs eza/starship expect; the fonts module only
    # carries the plain faces (stylix owns the rest on linux, no stylix here)
    nerd-fonts.caskaydia-cove

    # everyday cli
    gh
    htop
    ncdu
    yq
    yt-dlp
    exiftool
    sox
    socat
    ssh-audit
    wakeonlan
    nikto
    esptool
    dovi-tool
    cowsay
    fortune
  ];
}
