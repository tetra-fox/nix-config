{
  pkgs,
  lib,
  config,
  ...
}:

{
  programs.vscode = {
    enable = true;
    package = pkgs.code-cursor;
    mutableExtensionsDir = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        # looks
        catppuccin.catppuccin-vsc
        vscode-icons-team.vscode-icons

        # language support
        jnoortheen.nix-ide

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
        # anthropic.claude-code
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
