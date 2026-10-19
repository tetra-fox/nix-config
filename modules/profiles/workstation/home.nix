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

  # claude-code re-registers its claude-cli:// handler when this file lacks Exec="<its store
  # path>", rewriting mimeapps.list under home-manager. this matches its check, so it never does
  xdg.dataFile."applications/claude-code-url-handler.desktop".text = ''
    [Desktop Entry]
    Name=Claude Code URL Handler
    Comment=Handle claude-cli:// deep links for Claude Code
    Exec="${pkgs.claude-code}/bin/.claude-wrapped" --handle-uri %u
    Type=Application
    NoDisplay=true
    MimeType=x-scheme-handler/claude-cli;
  '';
  xdg.mimeApps.defaultApplications."x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";

  home.packages = with pkgs; [
    ungoogled-chromium

    cinny-desktop

    vlc
    qview

    kicad

    onlyoffice-desktopeditors
    obsidian-with-sops

    parsec-bin

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
