{
  modules,
  pkgs,
  ...
}: {
  imports = [
    modules.vscode.languages.all
  ];

  programs.vscodium = {
    enable = true;
    mutableExtensionsDir = false;
    profiles.default = {
      extensions = with pkgs.open-vsx; [
        # looks
        catppuccin.catppuccin-vsc
        vscode-icons-team.vscode-icons

        # general tooling
        albert.tabout
        anthropic.claude-code
        esbenp.prettier-vscode
        jeanp413.open-remote-ssh
        ultram4rine.vscode-choosealicense
      ];

      userSettings = {
        # workbench
        "workbench.iconTheme" = "vscode-icons";
        "workbench.startupEditor" = "none";

        # editor
        "editor.fontLigatures" = true;
        "editor.formatOnSave" = true;
        "editor.stickyScroll.enabled" = true;

        # files
        "files.eol" = "\n";
        "files.insertFinalNewline" = true;
        "files.trimFinalNewlines" = true;
        "files.trimTrailingWhitespace" = true;

        # terminal
        "terminal.integrated.fontLigatures.enabled" = true;

        # git
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

        # claude-code
        "claudeCode.preferredLocation" = "sidebar";
        "claudeCode.claudeProcessWrapper" = "${pkgs.claude-code}/bin/claude";
      };
    };
  };
}
