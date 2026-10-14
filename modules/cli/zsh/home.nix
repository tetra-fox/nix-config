{
  lib,
  pkgs,
  inputs,
  ...
}: let
  zinput = lib.mkOrder 500 ''
    source ${./zinputrc}
  '';
  # zsh-autocomplete defaults this to unbounded and stats every entry on the first
  # prompt. must be set before its first precmd, it only defaults an unset style
  recentDirsCap = lib.mkOrder 500 ''
    zstyle ':chpwd:*' recent-dirs-max 20
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
  # from 26.08.03 the async engine is in the z-async submodule, which nixpkgs doesn't
  # fetch, so every prompt errors. the hash is tied to the rev, bump it with nixpkgs
  # TODO: drop once pkgs/by-name/zs/zsh-autocomplete sets fetchSubmodules
  autocompleteSrc =
    if lib.versionAtLeast pkgs.zsh-autocomplete.version "26.08.03"
    then
      pkgs.fetchFromGitHub {
        owner = "marlonrichert";
        repo = "zsh-autocomplete";
        rev = pkgs.zsh-autocomplete.version;
        fetchSubmodules = true;
        # upstream's .gitmodules has z-async at git@github.com:, the sandbox has no ssh
        # TODO: drop with the block above, or sooner if upstream fixes .gitmodules
        gitConfigFile = pkgs.writeText "zsh-autocomplete-gitconfig" ''
          [url "https://github.com/"]
          	insteadOf = git@github.com:
        '';
        hash = "sha256-XKreHmT3vkvYWk8IbGWv9RR/V5nIohcE/ck1SPjI++U=";
      }
    else "${pkgs.zsh-autocomplete}/share/zsh-autocomplete";
  # 26.05-darwin predates zsh-patina's nixpkgs packaging
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
      envExtra = "setopt no_global_rcs";
      # rebuild the compdump daily or when the plugin path changes. zsh-autocomplete's
      # own mtime check never fires because store files have mtime 1
      completionInit = ''
        () {
          setopt local_options extendedglob
          local _zac_dump=''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compdump
          local _zac_stamp=$_zac_dump.src
          if [[ -n $_zac_dump(#qN.mh+24) ]] ||
             [[ ! -r $_zac_stamp || "$(<$_zac_stamp)" != ${autocompleteSrc} ]]; then
            rm -f "$_zac_dump"
            mkdir -p "''${_zac_dump:h}"
            print -r -- ${autocompleteSrc} > "$_zac_stamp"
          fi
          zstyle ':autocomplete::compinit' arguments -C
        }
      '';
      shellAliases = {
        zj = lib.getExe pkgs.zellij;
      };
      history = {
        ignoreAllDups = true;
      };
      initContent = lib.mkMerge [
        sudoToggle
        zinput
        recentDirsCap
        zshPatina
      ];
      plugins = [
        {
          name = "zsh-autocomplete";
          src = autocompleteSrc;
        }
      ];
    };
  };
}
