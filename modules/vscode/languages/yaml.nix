{...}: {
  programs.vscode.profiles.default.userSettings = {
    "[yaml]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
  };
}
