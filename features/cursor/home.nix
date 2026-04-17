{
  pkgs,
  lib,
  config,
  ...
}:

let
  qt-qml = pkgs.vscode-utils.extensionFromVscodeMarketplace {
    publisher = "theqtcompany";
    name = "qt-qml";
    version = "1.13.0";
    sha256 = "0walz6d6miawdkbgwmgqvmshbznigh65rx2nfn3wyh6bnmxf5z2q";
  };
  qt-core = pkgs.vscode-utils.extensionFromVscodeMarketplace {
    publisher = "theqtcompany";
    name = "qt-core";
    version = "1.13.0";
    sha256 = "18rq8my8c58lsfpqn3p4xvl1llh0bgxqxy49dpnz4fczc8k2h87x";
  };
in
{
  home.packages = with pkgs; [
    kdePackages.qtdeclarative # provides qmlls
  ];

  programs.vscode = {
    enable = true;
    package = pkgs.code-cursor;
    mutableExtensionsDir = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        # looks
        catppuccin.catppuccin-vsc
        vscode-icons-team.vscode-icons

        # language support - nix
        jnoortheen.nix-ide

        # language support - qt (i know its not a language)
        qt-core
        qt-qml

        # language support - rust
        rust-lang.rust-analyzer
        tamasfe.even-better-toml

        # language support - lua
        sumneko.lua

        # language support - nodejs
        dbaeumer.vscode-eslint
        yoavbls.pretty-ts-errors

        # language support - svelte
        svelte.svelte-vscode

        # tooling
        anthropic.claude-code
        esbenp.prettier-vscode
      ];
      userSettings = {
        "workbench.colorTheme" = "Catppuccin Mocha";
        "workbench.iconTheme" = "vscode-icons";

        "editor.fontFamily" = "Cascadia Code";
        "editor.fontSize" = 14;
        "editor.fontLigatures" = true;
        "editor.formatOnSave" = true;

        "terminal.integrated.fontFamily" = lib.head config.fonts.fontconfig.defaultFonts.monospace;
        "terminal.integrated.fontSize" = 14;
        "terminal.integrated.fontLigatures.enabled" = true;

        "claudeCode.preferredLocation" = "panel";

        "git.autofetch" = true;
        "git.confirmSync" = false;
        "git.enableSmartCommit" = true;

        # language specific
        "[json]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };

        "[markdown]" = {
          "editor.wordWrap" = "on";
          "editor.quickSuggestions" = {
            "comments" = "on";
            "strings" = "on";
            "other" = "on";
          };
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };

        "[yaml]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };

        "[toml]" = {
          "editor.defaultFormatter" = "tamasfe.even-better-toml";
        };

        "[javascript]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };

        "[typescript]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };
      };
    };
  };
}
