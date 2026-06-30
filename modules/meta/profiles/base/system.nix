{
  lib,
  modules,
  pkgs,
  username,
  ...
}: {
  imports = [
    modules.platform.fstrim.system
    modules.platform.nix.system
    modules.platform.nixpkgs.system
    modules.services.sshd.system
    modules.cli.zsh.system
    modules.platform.systemd-boot.system
  ];

  # the admin user, on every host (server + workstation -- both ran this identical block
  # before). a host adds extra groups (svc-01: podman/media; hara: the desktop set) by
  # appending to extraGroups -- the lists merge. uid is mkDefault so a host can override.
  users.users.${username} = {
    isNormalUser = true;
    uid = lib.mkDefault 1000;
    extraGroups = ["wheel"];
  };

  time.timeZone = lib.mkDefault "UTC";

  i18n = {
    defaultLocale = lib.mkDefault "en_US.UTF-8";
    extraLocaleSettings = lib.mkDefault {
      LC_TIME = "en_GB.UTF-8"; # 24h, DD/MM
      LC_MEASUREMENT = "en_GB.UTF-8"; # metric
    };
  };

  console.keyMap = lib.mkDefault "us";

  # nftables backend everywhere. it's the modern default (iptables is the legacy
  # compat shim over nft now), and source-scoped firewall.extraInputRules are silently
  # ignored under the iptables backend -- several modules rely on them (monitoring,
  # logging, the store NFS export), so this is the single place that flag lives.
  networking.nftables.enable = lib.mkDefault true;

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
