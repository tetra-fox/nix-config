{
  lib,
  modules,
  pkgs,
  ...
}: {
  imports = [
    modules.profiles.workstation.home-common

    modules.cli.ghostty.home
  ];

  my.ssh.opVaults = ["Private" "mesa" "fairlane"];

  # the flake-input build has no x86_64-darwin cache, nixpkgs' is on hydra
  programs.yazi.package = lib.mkForce pkgs.yazi;

  home.packages = with pkgs; [
    poetry

    ansible
    opentofu
    packer
    influxdb2-cli

    # no stylix on darwin, the fonts module only carries plain faces
    nerd-fonts.caskaydia-cove

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
