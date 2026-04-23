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
    modules.nvidia.system
    modules.obs-studio.system
    modules.onepassword.system
    # modules.openrgb.system
    modules.pipewire.system
    modules.pipewire-rnnoise.system
    modules.sshd.system
    modules.steam.system
    modules.systemd-boot.system
    modules.zsh.system
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
