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

  environment.systemPackages = with pkgs; [
    git
    jq
    ripgrep
    tree
    pv

    htop
    lsof
    smartmontools

    wget
    bind
    nmap
    mtr

    unzip
    p7zip
    unrar

    kitty.terminfo
  ];
}
