{pkgs, ...}: {
  programs.vscode.profiles.default = {
    extensions = with pkgs.open-vsx; [
      davidanson.vscode-markdownlint
    ];
    userSettings = {
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
    };
  };
}
