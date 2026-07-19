# the platform-agnostic core of the workstation home, shared by the linux
# face (home.nix) and the darwin hosts; keeps the mac's cli experience in
# lockstep with the linux workstations
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
    modules.cli.ssh.home
    modules.cli.yazi.home
    modules.desktop.fonts.home
    modules.desktop.vscode.home
  ];

  # the operator identity from flake.nix, stated once for every workstation
  my.git.identity = identity;

  home.packages = with pkgs; [
    # dev toolchains
    rustup
    pnpm
    nodejs
    python3

    # everyday cli
    sqlite
    gh
    claude-code
    alejandra
    ffmpeg
    yt-dlp
    ncdu
    iperf3
  ];
}
