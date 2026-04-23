{
  pkgs,
  username,
  features,
  quirks,
  ...
}: {
  imports = [
    quirks
    features.bluetooth.system
    features.cosmic.system
    features.docker.system
    features.fstrim.system
    features.greetd.system
    features.hyprland.system
    features.nix.system
    features.nvidia.system
    features.obs-studio.system
    features.onepassword.system
    # features.openrgb.system
    features.pipewire.system
    features.pipewire-rnnoise.system
    features.sshd.system
    features.steam.system
    features.systemd-boot.system
    features.zsh.system
  ];

  networking = {
    networkmanager.enable = true;
    hostName = "hara";
    firewall = {
      # enable = false;
      allowedTCPPorts = [53];
      allowedUDPPorts = [53];
    };
  };

  # locale
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  environment.systemPackages = with pkgs; [
    git
    wget
    jq
    bash
    ripgrep
    htop
    unzip
    bind
    unrar
    eza
  ];

  programs.dconf.enable = true;
  services.dbus.implementation = "broker";

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # needed for precompiled binaries that expect FHS glibc paths
      # vscode extensions, some steam games, electron apps not in nixpkgs
      glibc
    ];
  };

  services.printing.enable = true;

  # paws off!
  system.stateVersion = "25.11";
}
