{
  lib,
  modules,
  pkgs,
  ...
}: {
  imports = [
    modules.profiles.workstation.home-common

    # trialing as the fleet terminal; hara still runs kitty
    modules.cli.ghostty.home
  ];

  # matches the pre-nix agent.toml this file replaces
  my.ssh.opVaults = ["Private" "mesa" "fairlane"];

  # the yazi module's flake-input build has no x86_64-darwin cache and would
  # compile the whole crate graph here; the nixpkgs build is on hydra
  programs.yazi.package = lib.mkForce pkgs.yazi;

  # mac-only extras on top of the shared workstation core; former brew
  # formulae with straight nixpkgs equivalents (what's left in homebrew.brews
  # is mac-only or brew-only)
  home.packages = with pkgs; [
    # dev toolchains
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
    htop
    yq
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
