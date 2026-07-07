{
  modules,
  pkgs,
  lib,
  ...
}: {
  imports = [
    modules.desktop.vscode.languages.all
  ];

  # vscodium-devpodcontainers shells out to the devpod cli
  home.packages = [pkgs.devpod];

  # devpodcontainers needs proposed apis enabled via argv.json, which programs.vscodium doesn't expose
  # https://github.com/3timeslazy/vscodium-devpodcontainers#requirements
  xdg.configFile."VSCodium/argv.json".text = lib.generators.toJSON {} {
    "enable-proposed-api" = ["3timeslazy.vscodium-devpodcontainers"];
  };

  programs.vscodium = {
    enable = true;
    mutableExtensionsDir = false;
    profiles.default = {
      extensions = with pkgs.open-vsx; [
        catppuccin.catppuccin-vsc
        vscode-icons-team.vscode-icons

        albert.tabout
        anthropic.claude-code
        sst-dev.opencode
        esbenp.prettier-vscode
        jeanp413.open-remote-ssh
        ultram4rine.vscode-choosealicense
        pkgs.open-vsx."3timeslazy".vscodium-devpodcontainers
      ];

      userSettings = {
        "workbench.iconTheme" = "vscode-icons";
        "workbench.startupEditor" = "none";

        "editor.fontLigatures" = true;
        "editor.formatOnSave" = true;
        "editor.stickyScroll.enabled" = true;

        "files.eol" = "\n";
        "files.insertFinalNewline" = true;
        "files.trimFinalNewlines" = true;
        "files.trimTrailingWhitespace" = true;

        "terminal.integrated.fontLigatures.enabled" = true;

        "git.autofetch" = true;
        "git.confirmSync" = false;
        "git.enableSmartCommit" = true;
        "git.inputValidation" = true;
        "git.inputValidationSubjectLength" = 50;
        "git.inputValidationLength" = 72;

        # nix manages the editor and extensions; don't let the GUI fight it
        "telemetry.telemetryLevel" = "off";
        "update.mode" = "none";
        "extensions.autoCheckUpdates" = false;
        "extensions.autoUpdate" = false;

        "prettier.prettierPath" = "${pkgs.prettier}/lib/node_modules/prettier";

        "claudeCode.preferredLocation" = "sidebar";
        "claudeCode.claudeProcessWrapper" = "${pkgs.claude-code}/bin/claude";
      };
    };
  };
}
