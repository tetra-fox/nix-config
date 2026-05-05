{pkgs, ...}: {
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
      "qt-qml.qmlls.customExePath" = "${pkgs.kdePackages.qtdeclarative}/bin/qmlls";
      "qt-qml.doNotAskForQmllsDownload" = true;
      "qmlFormat.command" = "${pkgs.kdePackages.qtdeclarative}/bin/qmlformat";
      "[qml]" = {
        "editor.defaultFormatter" = "delgan.qml-format";
      };
    };
  };
}
