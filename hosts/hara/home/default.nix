{
  pkgs,
  inputs,
  config,
  username,
  modules,
  ...
}: {
  imports = [
    modules.catppuccin.home
    modules.cosmic.home
    modules.direnv.home
    modules.vscode.home
    modules.fastfetch.home
    modules.firefox.home
    modules.fonts.home
    modules.git.home
    modules.helix.home
    modules.hyprland.home
    modules.kitty.home
    modules.nvidia.home
    modules.obs-studio.home
    # modules.openrgb.home
    modules.ssh.home
    modules.starship.home
    modules.steam.home
    modules.stylix.home
    modules.surge-dm.home
    modules.walker.home
    modules.zsh.home
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  my.git.identity = {
    name = "tetra";
    email = "me@tetra.cool";
    signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHseoQ278Qrc45S8MUE8vwXnmdxd8OiWXViK0yHYYELz";
  };

  systemd.user.sessionVariables = config.home.sessionVariables;

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  home.packages = with pkgs; [
    # cli
    eza

    # chat / comms
    telegram-desktop
    discord
    signal-desktop
    cinny-desktop

    # media / creative
    vlc
    cider-2
    bitwig-studio
    tenacity
    blender

    # productivity
    onlyoffice-desktopeditors

    # gaming
    (prismlauncher.override {
      jdks = [
        javaPackages.compiler.temurin-bin.jre-25
        javaPackages.compiler.temurin-bin.jre-21
        javaPackages.compiler.temurin-bin.jre-17
        javaPackages.compiler.temurin-bin.jre-8
      ];
    })
    (bottles.override {removeWarningPopup = true;})
    vrcx

    # p2p
    nicotine-plus
    qbittorrent

    # system / gui utils
    kdePackages.dolphin
    vulkan-tools # vulkaninfo, vkcube
    iperf3
    ethtool
    wireshark

    # dev — languages / runtimes
    rustup
    gcc
    gnumake
    pnpm
    nodejs
    python3

    # dev — tools
    sqlite
    gh
    dbeaver-bin
    claude-code
    lldb
    inputs.alejandra.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # paws off!
  home.stateVersion = "26.05";
}
