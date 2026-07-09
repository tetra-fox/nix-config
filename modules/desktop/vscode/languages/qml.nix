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
      # the quickshell qs.* modules live in a hash-named runtime vfs under /run;
      # debug.sh in the quickshell module mirrors it at this stable path. the
      # Quickshell/Qt modules themselves resolve through the session's
      # QML2_IMPORT_PATH (per-user profile qml dir), which qmlls reads natively
      "qt-qml.qmlls.additionalImportPaths" = ["${config.xdg.stateHome}/quickshell/qmlls-vfs"];
      "qt-qml.qmlls.customExePath" = "${pkgs.kdePackages.qtdeclarative}/bin/qmlls";
      "qt-qml.doNotAskForQmllsDownload" = true;
      "qmlFormat.command" = "${pkgs.kdePackages.qtdeclarative}/bin/qmlformat";
      "[qml]" = {
        "editor.defaultFormatter" = "delgan.qml-format";
      };
    };
  };
}
