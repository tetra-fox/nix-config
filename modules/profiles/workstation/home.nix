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
    modules.udiskie.home
    modules.vscode.home
    modules.walker.home
    modules.yazi.home
  ];

  my.git.identity = {
    name = "tetra";
    email = "me@tetra.cool";
    signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHseoQ278Qrc45S8MUE8vwXnmdxd8OiWXViK0yHYYELz";
  };

  # dark mode in gtk/gnome apps via dconf (gtk-theme handled by stylix)
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  home.packages = with pkgs; [
    sops

    telegram-desktop
    discord
    signal-desktop
    cinny-desktop

    vlc
    qview

    onlyoffice-desktopeditors
    obsidian

    parsec-bin

    nicotine-plus
    qbittorrent

    vulkan-tools
    iperf3
    ethtool
    ffmpeg
    yt-dlp
    imhex
    ncdu

    rustup
    gcc
    gnumake
    pnpm
    nodejs
    python3

    sqlite
    gh
    dbeaver-bin
    claude-code
    lldb
    inputs.alejandra.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
