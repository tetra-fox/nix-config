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
  # nixpkgs carries zsh-patina on unstable (linux, hydra-cached); 26.05-darwin
  # predates its packaging, so the mac builds the flake's package against the
  # darwin nixpkgs pin instead
  patina = pkgs.zsh-patina or inputs.zsh-patina.packages.${pkgs.stdenv.hostPlatform.system}.default;
  zshPatina = lib.mkOrder 1000 ''
    eval "$(${lib.getExe' patina "zsh-patina"} activate)"
  '';
in {
  home.packages = with pkgs; [
    nix-zsh-completions
  ];

  programs = {
    eza = {
      enable = true;
      enableZshIntegration = true;
      icons = "auto";
      git = true;
      extraOptions = ["--group-directories-first"];
    };
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      # disable global rc files (nix-generated)
      envExtra = "setopt no_global_rcs";
      # rebuild the compdump at most once per 24h; force a rebuild with `rm ~/.cache/zsh/compdump`
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
        nix-cleanup = "sudo nix-collect-garbage -d && nix-collect-garbage -d && sudo nix store optimise";
      };
      history = {
        ignoreAllDups = true;
      };
      initContent = lib.mkMerge [
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
