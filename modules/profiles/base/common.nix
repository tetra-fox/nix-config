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
    modules.cli.nix-purge.system
  ];

  # on every host, workstation or server: what you reach for on a box you ssh'd
  # into to find out why something broke. situational kit (disk, net, observe,
  # hardware) stays in modules/toolsets and is imported per host
  environment.systemPackages = with pkgs;
    [
      _7zz # upstream 7-zip, binary is 7zz. the older p7zip fork is unmaintained
      bind # dig/nslookup for dns debugging
      btop
      fd
      file
      jq
      lsof
      mtr
      ncdu
      pv
      ripgrep
      tree
      unrar
      unzip
      wget
      yq-go # jq for yaml, which is the shape sops secrets and most service config come in
      zellij
      zip
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
