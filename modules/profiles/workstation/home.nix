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
    ./home-common.nix

    modules.desktop.firefox.home
    modules.cli.kitty.home
    modules.desktop.obs-studio.home
    modules.desktop.udiskie.home
    modules.desktop.walker.home
    modules.desktop.discord.home
  ];

  my = {
    # personal 1password vaults the ssh agent may serve keys from
    ssh.opVaults = ["Private" "mesa" "homelab_DTW"];

    # bookmark data lives in the private nix-secrets input; referenced here (the personal
    # profile) so the firefox module itself works without that input
    firefox.bookmarks = inputs.nix-secrets.lib.firefox-bookmarks;
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
    ethtool
    imhex

    gcc
    gnumake

    alcom
    unityhub

    davinci-resolve

    dbeaver-bin
    lldb
  ];
}
