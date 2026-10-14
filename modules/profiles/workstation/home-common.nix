# shared by home.nix and the darwin hosts
{
  identity,
  modules,
  pkgs,
  ...
}: {
  imports = [
    modules.profiles.base.home

    modules.cli.direnv.home
    modules.cli.fastfetch.home
    modules.cli.git.home
    modules.cli.helix.home
    modules.cli.sops.home
    modules.cli.ssh.home
    modules.cli.yazi.home
    modules.desktop.fonts.home
    modules.desktop.vscode.home
  ];

  my.git.identity = identity;

  home.packages = with pkgs; [
    rustup
    pnpm
    nodejs
    python3
    sqlite
    gh
    claude-code
    alejandra
    ffmpeg
    yt-dlp
  ];
}
