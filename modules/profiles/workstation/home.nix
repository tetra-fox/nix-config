{
  modules,
  pkgs,
  inputs,
  ...
}: let
  # obsidian's git plugin runs the vault's sops clean/smudge filter with obsidian's PATH
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

    modules.desktop.zen-browser.home
    modules.cli.kitty.home
    modules.desktop.obs-studio.home
    modules.desktop.udiskie.home
    modules.desktop.discord.home
    modules.desktop.telegram.home
    modules.desktop.signal.home
    modules.desktop.vicinae.home
    modules.desktop.artcraft.home
  ];

  my = {
    ssh.opVaults = ["Private" "mesa" "homelab_DTW"];

    # set here so the browser module works without the private nix-secrets input
    zen-browser.bookmarks = inputs.nix-secrets.lib.firefox-bookmarks;
  };

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  home.packages = with pkgs; [
    ungoogled-chromium

    cinny-desktop

    vlc
    qview

    kicad

    onlyoffice-desktopeditors
    obsidian-with-sops

    parsec-bin

    nicotine-plus
    qbittorrent

    vulkan-tools
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
