{
  pkgs,
  username,
  modules,
  quirks,
  ...
}: {
  imports = [
    quirks
    modules.bluetooth.system
    modules.cosmic.system
    modules.docker.system
    modules.fstrim.system
    modules.greetd.system
    modules.hyprland.system
    modules.nix.system
    modules.nixpkgs.system
    modules.nvidia.system
    modules.obs-studio.system
    modules.onepassword.system
    # modules.openrgb.system
    modules.pipewire.system
    modules.pipewire-rnnoise.system
    modules.sshd.system
    modules.steam.system
    modules.stylix.system
    modules.systemd-boot.system
    modules.wireshark.system
    modules.zsh.system
  ];

  networking = {
    networkmanager.enable = true;
    hostName = "hara";
  };

  # locale
  time.timeZone = "America/Los_Angeles";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "en_GB.UTF-8"; # 24h, DD/MM
      LC_MEASUREMENT = "en_GB.UTF-8"; # metric
    };
  };

  console.keyMap = "us";

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  environment.systemPackages = with pkgs; [
    # shell / text
    jq
    ripgrep
    tree

    # net
    wget
    bind # dig, host, nslookup
    nmap # also provides nc
    mtr
    rclone

    # hardware / system inspection
    htop
    usbutils # lsusb
    lsof
    smartmontools # smartctl

    # archives
    unzip
    unrar
    p7zip

    # vcs
    git

    # misc
    pv
  ];

  programs = {
    dconf.enable = true;
    command-not-found.enable = true;
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        # needed for precompiled binaries that expect FHS glibc paths
        # vscode extensions, some steam games, electron apps not in nixpkgs
        glibc
      ];
    };
  };

  services = {
    printing.enable = true;
    dbus.implementation = "broker";
    fwupd.enable = true;
    earlyoom.enable = true;
  };

  boot.tmp.cleanOnBoot = true;

  # paws off!
  system.stateVersion = "25.11";
}
