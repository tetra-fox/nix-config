{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    mutableExtensionsDir = true;
    profiles.default = {
      extensions = with pkgs.open-vsx;
        [
          # looks
          catppuccin.catppuccin-vsc
          vscode-icons-team.vscode-icons

          # language support - nix
          jnoortheen.nix-ide

          # language support - qt (i know its not a language)
          theqtcompany.qt-core
          theqtcompany.qt-qml
          delgan.qml-format

          # language support - rust
          rust-lang.rust-analyzer
          tamasfe.even-better-toml

          # language support - lua
          sumneko.lua

          # language support - nodejs
          dbaeumer.vscode-eslint
          yoavbls.pretty-ts-errors
          denoland.vscode-deno

          # language support - svelte
          svelte.svelte-vscode

          # language support - sieve
          adzero.vscode-sievehighlight

          # language support - markdown
          davidanson.vscode-markdownlint

          # language support - shell
          foxundermoon.shell-format

          # tooling
          anthropic.claude-code
          esbenp.prettier-vscode
          albert.tabout
          bradlc.vscode-tailwindcss
          jeanp413.open-remote-ssh
        ]
        ++ (with pkgs.vscode-marketplace; [
          # in case we need extensions NOT available on openvsx
        ]);
      userSettings = {
        "workbench.colorTheme" = "Catppuccin Mocha";
        "workbench.iconTheme" = "vscode-icons";
        "workbench.editorAssociations" = {
          "{git,gitlens,chat-editing-snapshot-text-model,copilot,git-graph,git-graph-3}:/**/*.qrc" = "default";
          "*.qrc" = "qt-core.qrcEditor";
        };

        "editor.fontFamily" = "Cascadia Code";
        "editor.fontSize" = 14;
        "editor.fontLigatures" = true;
        "editor.formatOnSave" = true;

        "terminal.integrated.fontFamily" = lib.head config.fonts.fontconfig.defaultFonts.monospace;
        "terminal.integrated.fontSize" = 14;
        "terminal.integrated.fontLigatures.enabled" = true;

        "claudeCode.preferredLocation" = "sidebar";
        "claudeCode.claudeProcessWrapper" = "${pkgs.claude-code}/bin/claude";

        # nix
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "${pkgs.nixd}/bin/nixd";
        "nix.formatterPath" = "${
          inputs.alejandra.packages.${pkgs.stdenv.hostPlatform.system}.default
        }/bin/alejandra";
        "nix.serverSettings" = {
          nixd = {
            formatting.command = [
              "${inputs.alejandra.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/alejandra"
            ];
          };
        };
        "[nix]" = {
          "editor.defaultFormatter" = "jnoortheen.nix-ide";
        };

        "git.autofetch" = true;
        "git.confirmSync" = false;
        "git.enableSmartCommit" = true;

        # language specific
        "[json]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };

        # qml
        "[qml]" = {
          "editor.defaultFormatter" = "delgan.qml-format";
        };
        "qt-qml.qmlls.useQmlImportPathEnvVar" = true;
        "qt-qml.qmlls.customExePath" = "${pkgs.kdePackages.qtdeclarative}/bin/qmlls";
        "qmlFormat.command" = "${pkgs.kdePackages.qtdeclarative}/bin/qmlformat";
        "qt-qml.doNotAskForQmllsDownload" = true;

        # shell
        "shellformat.path" = "${pkgs.shfmt}/bin/shfmt";
        "[shellscript]" = {
          "editor.defaultFormatter" = "foxundermoon.shell-format";
        };

        # rust
        "rust-analyzer.server.path" = "${pkgs.rust-analyzer}/bin/rust-analyzer";
        "[rust]" = {
          "editor.defaultFormatter" = "rust-lang.rust-analyzer";
        };

        # lua
        "Lua.misc.executablePath" = "${pkgs.lua-language-server}/bin/lua-language-server";
        "[lua]" = {
          "editor.defaultFormatter" = "sumneko.lua";
        };

        # svelte
        "[svelte]" = {
          "editor.defaultFormatter" = "svelte.svelte-vscode";
        };

        # deno
        "deno.path" = "${pkgs.deno}/bin/deno";

        # toml
        "evenBetterToml.taplo.bundled" = false;
        "evenBetterToml.taplo.path" = "${pkgs.taplo}/bin/taplo";

        "[markdown]" = {
          "editor.wordWrap" = "on";
          "editor.quickSuggestions" = {
            "comments" = "on";
            "strings" = "on";
            "other" = "on";
          };
          "editor.defaultFormatter" = "DavidAnson.vscode-markdownlint";
          "editor.codeActionsOnSave" = {
            "source.fixAll.markdownlint" = "explicit";
          };
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
