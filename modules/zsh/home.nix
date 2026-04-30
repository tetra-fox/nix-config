{
  config,
  lib,
  pkgs,
  inputs,
  username,
  ...
}: let
  profiler = lib.mkBefore ''
    zmodload zsh/zprof
  '';
  zinput = lib.mkOrder 500 ''
    source ${./zinputrc}
  '';
  sudoToggle = lib.mkOrder 1000 ''
    sudo-command-line() {
      if [[ -z $BUFFER ]]; then
        BUFFER="sudo $(fc -ln -1)"
      elif [[ $BUFFER == sudo\ * ]]; then
        BUFFER="''${BUFFER#sudo }"
      else
        BUFFER="sudo $BUFFER"
      fi
      CURSOR=''${#BUFFER}
    }
    zle -N sudo-command-line
    bindkey "\e\e" sudo-command-line
  '';
  zshPatina = lib.mkOrder 1000 ''
    eval "$(${
      inputs.zsh-patina.packages.${pkgs.stdenv.hostPlatform.system}.default
    }/bin/zsh-patina activate)"
  '';
in {
  home.packages = with pkgs; [
    eza
    nix-zsh-completions
  ];

  programs = {
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      # disable global rc files (nix-generated)
      envExtra = "setopt no_global_rcs";
      # compdump cache rebuilt at most once per 24h; ~4x faster shell init for
      # the rest of the day after the first rebuild. force a rebuild with
      # `rm ~/.cache/zsh/compdump`.
      completionInit = ''
        () {
          setopt local_options extendedglob
          local _zac_dump=''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compdump
          if [[ -n $_zac_dump(#qN.mh+24) ]]; then
            rm -f "$_zac_dump"
          fi
          zstyle ':autocomplete::compinit' arguments -C
        }
      '';
      shellAliases = {
        ls = "eza --group-directories-first --icons";
        lsa = "eza --group-directories-first --all --icons";
        la = "eza -lbhHgmuSa --group-directories-first --color-scale --icons";
        lx = "eza -lbhHgmuSa@ --group-directories-first --color-scale --icons";
        llt = "eza -l --git --tree --icons";
        lt = "eza --tree --level=2 --all --icons";
        lld = "eza -lbhHFGmuSa --group-directories-first --icons";

        nix-cleanup = "sudo nix-collect-garbage -d && nix-collect-garbage -d && sudo nix store optimise";
      };
      history = {
        ignoreAllDups = true;
      };
      initContent = lib.mkMerge [
        # profiler
        sudoToggle
        zinput
        zshPatina
      ];
      plugins = [
        {
          name = "zsh-autocomplete";
          src = pkgs.zsh-autocomplete.src;
        }
      ];
    };
  };
}
