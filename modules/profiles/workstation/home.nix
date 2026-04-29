# workstation home: base + workstation-only conveniences
{
  modules,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    modules.profiles.base.home

    modules.direnv.home
    modules.fastfetch.home
    modules.firefox.home
    modules.fonts.home
    modules.git.home
    modules.helix.home
    modules.kitty.home
    modules.obs-studio.home
    modules.ssh.home
    modules.vscode.home
    modules.walker.home
    modules.yazi.home
  ];

  my.git.identity = {
    name = "tetra";
    email = "me@tetra.cool";
    signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHseoQ278Qrc45S8MUE8vwXnmdxd8OiWXViK0yHYYELz";
  };

  # dark mode in GTK/GNOME apps via dconf (gtk-theme handled by stylix).
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  home.packages = with pkgs; [
    # secrets
    sops

    # chat / comms
    telegram-desktop
    discord
    signal-desktop
    cinny-desktop

    # media
    vlc
    qview

    # productivity
    onlyoffice-desktopeditors

    # remote desktop
    parsec-bin

    # p2p
    nicotine-plus
    qbittorrent

    # system / gui utils
    vulkan-tools # vulkaninfo, vkcube
    iperf3
    ethtool
    ffmpeg
    yt-dlp
    imhex
    ncdu

    # dev - languages / runtimes
    rustup
    gcc
    gnumake
    pnpm
    nodejs
    python3

    # dev - tools
    sqlite
    gh
    dbeaver-bin
    claude-code
    lldb
    inputs.alejandra.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
