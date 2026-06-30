{pkgs, ...}: {
  programs.vscodium.profiles.default = {
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
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
        "editor.formatOnSave" = true;
        "editor.codeActionsOnSave" = {
          "source.fixAll.markdownlint" = "explicit";
        };
      };
      # preserve so prettier doesn't reflow paragraphs into one long line under wordWrap
      "prettier.proseWrap" = "preserve";
    };
  };
}
