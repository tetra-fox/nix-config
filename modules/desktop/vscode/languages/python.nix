{pkgs, ...}: {
  programs.vscodium.profiles.default = {
    extensions =
      (with pkgs.open-vsx; [
        charliermarsh.ruff
        meta.pyrefly
      ])
      ++ (with pkgs.vscode-marketplace; [
        ms-python.python
      ]);
    userSettings = {
      "python.defaultInterpreterPath" = "${pkgs.python3}/bin/python3";
      # pyrefly is the LSP, suppress ms-python.python's pylance prompt
      "python.languageServer" = "Default";
      "pyrefly.lspPath" = "${pkgs.pyrefly}/bin/pyrefly";
      "ruff.path" = ["${pkgs.ruff}/bin/ruff"];
      "[python]" = {
        "editor.defaultFormatter" = "charliermarsh.ruff";
        "editor.codeActionsOnSave" = {
          "source.fixAll.ruff" = "explicit";
          "source.organizeImports.ruff" = "explicit";
        };
      };
    };
  };
}
