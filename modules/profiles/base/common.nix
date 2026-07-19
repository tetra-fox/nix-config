# the platform-agnostic core of the base profile, shared by the linux
# (system.nix) and darwin (darwin.nix) faces
{
  lib,
  modules,
  pkgs,
  ...
}: {
  imports = [
    modules.platform.nixpkgs.system
    modules.cli.zsh.system
  ];

  environment.systemPackages = with pkgs;
    [
      btop
      tmux
      lsof
      mtr
      bind # dig/nslookup for dns debugging
    ]
    # terminfo for the workstation terminals (kitty on hara, ghostty on the
    # mac) so ssh sessions from either render right on every fleet host.
    # linux-only: the terminals ship their own terminfo where they run, and
    # x86_64-darwin would have to build them from source for it
    ++ lib.optionals stdenv.isLinux [
      kitty.terminfo
      ghostty.terminfo
    ];
}
