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
  # zsh-autocomplete's recent-dirs module defaults recent-dirs-max to 0
  # (unbounded) and stats every entry on every shell's first prompt to build
  # its directory-completion list. Left uncapped that file grows forever;
  # setting this before the plugin's first precmd fires makes it respect our
  # cap instead (it only sets its own default if the style is unset).
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
  # nixpkgs fetches zsh-autocomplete with plain fetchFromGitHub, but from
  # 26.08.03 upstream moved the async engine out into the z-async submodule, so
  # the plugin autoloads a file that isn't there and errors on every prompt.
  # refetch those with submodules until nixpkgs sets fetchSubmodules itself.
  # the 26.05-darwin pin still carries 25.03.19, which has no .gitmodules at
  # all, so there it takes the packaged source unchanged.
  # TODO: drop this once pkgs/by-name/zs/zsh-autocomplete fetches submodules.
  # the hash is tied to the rev, so a nixpkgs version bump fails the build here
  # and needs a new one.
  autocompleteSrc =
    if lib.versionAtLeast pkgs.zsh-autocomplete.version "26.08.03"
    then
      pkgs.fetchFromGitHub {
        owner = "marlonrichert";
        repo = "zsh-autocomplete";
        rev = pkgs.zsh-autocomplete.version;
        fetchSubmodules = true;
        # upstream's .gitmodules points z-async at git@github.com:, the maintainer's
        # own push url (the sibling clitest submodule uses https). a sandboxed fetch
        # has no ssh binary and no key, so the submodule clone fails and takes every
        # linux build with it. rewrite it to https for the fetch only.
        # TODO: drop with the block above, or sooner if upstream fixes .gitmodules.
        gitConfigFile = pkgs.writeText "zsh-autocomplete-gitconfig" ''
          [url "https://github.com/"]
          	insteadOf = git@github.com:
        '';
        hash = "sha256-XKreHmT3vkvYWk8IbGWv9RR/V5nIohcE/ck1SPjI++U=";
      }
    else "${pkgs.zsh-autocomplete}/share/zsh-autocomplete";
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
      #
      # zsh-autocomplete already tries to invalidate the dump by comparing the
      # mtime of its newest Completions file against it, but every file in the
      # store has mtime 1, so that comparison never fires. combined with
      # compinit -C, which reuses the dump instead of rescanning fpath, a plugin
      # update leaves the dump advertising the old version's functions and
      # calling a newly added one fails. stamp the plugin path next to the dump
      # and rebuild whenever it changes.
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
