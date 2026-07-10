{
  modules,
  pkgs,
  inputs,
  ...
}: let
  # obsidian's git plugin shells out to git, which runs the sops clean/smudge
  # filter for the notes vault. that git subprocess inherits obsidian's PATH,
  # so sops and age have to be on it. wrap obsidian to prefix them rather than
  # installing sops globally.
  obsidian-with-sops = pkgs.symlinkJoin {
    name = "obsidian-with-sops";
    paths = [pkgs.obsidian];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/obsidian \
        --prefix PATH : ${pkgs.lib.makeBinPath [pkgs.sops pkgs.age]}
    '';
  };
in {
  imports = [
    modules.profiles.base.home

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

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  home.packages = with pkgs; [
    chromium

    telegram-desktop
    signal-desktop
    cinny-desktop

    vlc
    qview

    onlyoffice-desktopeditors
    obsidian-with-sops

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

    alcom
    unityhub

    davinci-resolve

    sqlite
    gh
    dbeaver-bin
    claude-code
    lldb
    alejandra
  ];
}
