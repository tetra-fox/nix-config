# universal baseline imported by every host (workstation or server).
{
  lib,
  modules,
  pkgs,
  ...
}: {
  imports = [
    modules.fstrim.system
    modules.nix.system
    modules.nixpkgs.system
    modules.sshd.system
    modules.zsh.system
    modules.systemd-boot.system
  ];

  time.timeZone = lib.mkDefault "UTC";

  i18n = {
    defaultLocale = lib.mkDefault "en_US.UTF-8";
    extraLocaleSettings = lib.mkDefault {
      LC_TIME = "en_GB.UTF-8"; # 24h, DD/MM
      LC_MEASUREMENT = "en_GB.UTF-8"; # metric
    };
  };

  console.keyMap = lib.mkDefault "us";

  services = {
    earlyoom.enable = true;
    dbus.implementation = "broker";
  };

  boot.tmp.cleanOnBoot = true;

  # universal toolkit
  environment.systemPackages = with pkgs; [
    # core
    git
    jq
    ripgrep
    tree
    pv

    # process / hardware inspection
    htop
    lsof
    smartmontools

    # network debugging
    wget
    bind
    nmap
    mtr

    # archives
    unzip
    p7zip
    unrar

    # terminal
    kitty.terminfo
  ];
}
