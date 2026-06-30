# workstation home: base + workstation-only conveniences
{
  modules,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    modules.meta.profiles.base.home

    modules.cli.direnv.home
    modules.cli.fastfetch.home
    modules.desktop.firefox.home
    modules.desktop.fonts.home
    modules.cli.git.home
    modules.cli.helix.home
    modules.cli.kitty.home
    modules.desktop.obs-studio.home
    modules.cli.ssh.home
    modules.desktop.udiskie.home
    modules.desktop.vscode.home
    modules.desktop.walker.home
    modules.cli.yazi.home
    modules.desktop.discord.home
  ];

  my.git.identity = {
    name = "tetra";
    email = "me@tetra.cool";
    signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHseoQ278Qrc45S8MUE8vwXnmdxd8OiWXViK0yHYYELz";
  };

  # dark mode in gtk/gnome apps via dconf (gtk-theme handled by stylix)
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  home.packages = with pkgs; [
    chromium

    telegram-desktop
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

    davinci-resolve

    sqlite
    gh
    dbeaver-bin
    claude-code
    lldb
    inputs.alejandra.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
