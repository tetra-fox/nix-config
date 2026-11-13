{
  config,
  pkgs,
  ...
}: {
  programs.vscodium.profiles.default = {
    extensions = with pkgs.open-vsx; [
      delgan.qml-format
      theqtcompany.qt-core
      theqtcompany.qt-qml
    ];
    userSettings = {
      "workbench.editorAssociations" = {
        "{git,gitlens,chat-editing-snapshot-text-model,copilot,git-graph,git-graph-3}:/**/*.qrc" = "default";
        "*.qrc" = "qt-core.qrcEditor";
      };
      "qt-qml.qmlls.useQmlImportPathEnvVar" = true;
      # qs.* modules live in a hash-named vfs under /run, debug.sh mirrors it here
      "qt-qml.qmlls.additionalImportPaths" = ["${config.xdg.stateHome}/quickshell/qmlls-vfs"];
      "qt-qml.qmlls.customExePath" = "${pkgs.kdePackages.qtdeclarative}/bin/qmlls";
      "qt-qml.doNotAskForQmllsDownload" = true;
      # qt-core writes any qtpaths found on PATH into this list on activation, which fails
      # on the read-only settings.json. it skips the write when the path is already listed
      "qt-core.additionalQtPaths" = [
        {
          name = "system-qt";
          path = "/run/current-system/sw/bin/qtpaths";
        }
      ];
      "qmlFormat.command" = "${pkgs.kdePackages.qtdeclarative}/bin/qmlformat";
      "[qml]" = {
        "editor.defaultFormatter" = "delgan.qml-format";
      };
    };
  };
}
