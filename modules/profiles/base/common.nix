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

  # situational kit lives in modules/toolsets, imported per host
  environment.systemPackages = with pkgs;
    [
      _7zz # p7zip is unmaintained
      bind # dig
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
      yq-go
      zellij
      zip
    ]
    # so ssh sessions from the workstation terminals render. darwin would have
    # to build them from source, and they ship their own terminfo there
    ++ lib.optionals stdenv.isLinux [
      kitty.terminfo
      ghostty.terminfo
    ];
}
