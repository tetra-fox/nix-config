{
  config,
  lib,
  pkgs,
  inputs,
  username,
  ...
}:
let
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
in
{
  programs = {
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      # disable global rc files (nix-generated)
      envExtra = "setopt no_global_rcs";
      # disable permissions check on completion files (improves startup time by 12x)
      completionInit = "zstyle '*:compinit' arguments -C";
      shellAliases = {
        ls = "eza --group-directories-first --icons";
        lsa = "eza --group-directories-first --all --icons";
        la = "eza -lbhHgmuSa --group-directories-first --color-scale --icons";
        lx = "eza -lbhHgmuSa@ --group-directories-first --color-scale --icons";
        llt = "eza -l --git --tree --icons";
        lt = "eza --tree --level=2 --all --icons";
        lld = "eza -lbhHFGmuSa --group-directories-first --icons";
        rebuild = "sudo nixos-rebuild switch --flake /home/${username}/Documents/git/nix-config#$(hostname)";
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
          file = "zsh-autocomplete.plugin.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "marlonrichert";
            repo = "zsh-autocomplete";
            rev = "25.03.19";
            sha256 = "sha256-eb5a5WMQi8arZRZDt4aX1IV+ik6Iee3OxNMCiMnjIx4=";
          };
        }
      ];
    };
  };
}
