{
  pkgs,
  inputs,
  ...
}: let
  alejandra = inputs.alejandra.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    mutableExtensionsDir = false;
    profiles.default = {
      # add `++ (with pkgs.vscode-marketplace; [...])` for extensions not on openvsx
      extensions = with pkgs.open-vsx;
        [
          # looks
          vscode-icons-team.vscode-icons

          # tooling
          albert.tabout
          anthropic.claude-code
          bradlc.vscode-tailwindcss
          esbenp.prettier-vscode
          jeanp413.open-remote-ssh
          ultram4rine.vscode-choosealicense

          # java
          redhat.java

          # json5
          blueglassblock.better-json5

          # lua
          sumneko.lua

          # markdown
          davidanson.vscode-markdownlint

          # nix
          jnoortheen.nix-ide

          # nodejs / typescript
          dbaeumer.vscode-eslint
          denoland.vscode-deno
          yoavbls.pretty-ts-errors

          # python
          charliermarsh.ruff
          meta.pyrefly

          # qt
          delgan.qml-format
          theqtcompany.qt-core
          theqtcompany.qt-qml

          # rust
          rust-lang.rust-analyzer

          # shell
          foxundermoon.shell-format

          # sieve
          adzero.vscode-sievehighlight

          # svelte
          svelte.svelte-vscode

          # toml
          tamasfe.even-better-toml
        ]
        ++ (with pkgs.vscode-marketplace; [
          ms-python.python
        ])
        ++ [
          # nix-vscode-extensions pins vscode-lldb to an unbuildable version;
          # use nixpkgs' own properly-wrapped build instead
          pkgs.vscode-extensions.vadimcn.vscode-lldb
        ];

      userSettings = {
        # workbench
        "workbench.iconTheme" = "vscode-icons";
        "workbench.editorAssociations" = {
          "{git,gitlens,chat-editing-snapshot-text-model,copilot,git-graph,git-graph-3}:/**/*.qrc" = "default";
          "*.qrc" = "qt-core.qrcEditor";
        };
        "workbench.startupEditor" = "none";

        # editor
        "editor.fontLigatures" = true;
        "editor.formatOnSave" = true;

        # terminal
        "terminal.integrated.fontLigatures.enabled" = true;

        # git
        "git.autofetch" = true;
        "git.confirmSync" = false;
        "git.enableSmartCommit" = true;

        # claude-code
        "claudeCode.preferredLocation" = "sidebar";
        "claudeCode.claudeProcessWrapper" = "${pkgs.claude-code}/bin/claude";

        # java
        "java.jdt.ls.java.home" = pkgs.javaPackages.compiler.temurin-bin.jdk-25.home;

        # json
        "[json]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };

        # lua
        "Lua.misc.executablePath" = "${pkgs.lua-language-server}/bin/lua-language-server";
        "[lua]" = {
          "editor.defaultFormatter" = "sumneko.lua";
        };

        # markdown
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

        # nix
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "${pkgs.nixd}/bin/nixd";
        # "nix.formatterPath" = "${alejandra}/bin/alejandra"; since nixd.formatting.command is set, this is ignored
        "nix.serverSettings" = {
          nixd = {
            formatting.command = ["${alejandra}/bin/alejandra"];
          };
        };
        "[nix]" = {
          "editor.defaultFormatter" = "jnoortheen.nix-ide";
        };

        # python
        "python.defaultInterpreterPath" = "${pkgs.python3}/bin/python3";
        "pyrefly.lspPath" = "${pkgs.pyrefly}/bin/pyrefly";
        "ruff.path" = ["${pkgs.ruff}/bin/ruff"];
        "[python]" = {
          "editor.defaultFormatter" = "charliermarsh.ruff";
          "editor.codeActionsOnSave" = {
            "source.fixAll.ruff" = "explicit";
            "source.organizeImports.ruff" = "explicit";
          };
        };

        # qml
        "qt-qml.qmlls.useQmlImportPathEnvVar" = true;
        "qt-qml.qmlls.customExePath" = "${pkgs.kdePackages.qtdeclarative}/bin/qmlls";
        "qt-qml.doNotAskForQmllsDownload" = true;
        "qmlFormat.command" = "${pkgs.kdePackages.qtdeclarative}/bin/qmlformat";
        "[qml]" = {
          "editor.defaultFormatter" = "delgan.qml-format";
        };

        # rust
        "rust-analyzer.server.path" = "${pkgs.rust-analyzer}/bin/rust-analyzer";
        "[rust]" = {
          "editor.defaultFormatter" = "rust-lang.rust-analyzer";
        };
        "lldb.library" = "${pkgs.lldb}/lib/liblldb.so";

        # shell
        "shellformat.path" = "${pkgs.shfmt}/bin/shfmt";
        "[shellscript]" = {
          "editor.defaultFormatter" = "foxundermoon.shell-format";
        };

        # svelte
        "[svelte]" = {
          "editor.defaultFormatter" = "svelte.svelte-vscode";
        };

        # toml
        "evenBetterToml.taplo.bundled" = false;
        "evenBetterToml.taplo.path" = "${pkgs.taplo}/bin/taplo";
        "[toml]" = {
          "editor.defaultFormatter" = "tamasfe.even-better-toml";
        };

        # typescript / javascript / deno
        "deno.path" = "${pkgs.deno}/bin/deno";
        "[javascript]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };
        "[typescript]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };

        # yaml
        "[yaml]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };
      };
    };
  };
}
