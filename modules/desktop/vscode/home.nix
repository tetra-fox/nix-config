{
  config,
  modules,
  pkgs,
  lib,
  ...
}: let
  # vscode's default fontFamily asks for "Droid Sans Mono" before the generic
  # monospace. that font isn't installed, but fontconfig substitutes rather than
  # failing, so vscode gets handed Noto Sans Mono and never falls through to the
  # generic, losing the nerd font glyphs. name the font instead of relying on
  # substitution. stylix owns the value where it runs; on darwin there is no
  # stylix and the fontconfig list is empty, so fall back to the fleet mono
  # (the fonts module installs it there)
  monospace =
    if config.fonts.fontconfig.defaultFonts.monospace != []
    then lib.head config.fonts.fontconfig.defaultFonts.monospace
    else "Cascadia Code";
in {
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

        "editor.fontFamily" = "'${monospace}', monospace";
        "editor.fontLigatures" = true;
        "editor.formatOnSave" = true;
        "editor.stickyScroll.enabled" = true;

        "files.eol" = "\n";
        "files.insertFinalNewline" = true;
        "files.trimFinalNewlines" = true;
        "files.trimTrailingWhitespace" = true;

        "terminal.integrated.fontFamily" = "'${monospace}', monospace";
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
