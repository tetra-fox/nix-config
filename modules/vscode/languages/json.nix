{pkgs, ...}: {
  programs.vscode.profiles.default = {
    extensions = with pkgs.open-vsx; [
      blueglassblock.better-json5
    ];
    userSettings = {
      "[json]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
    };
  };
}
