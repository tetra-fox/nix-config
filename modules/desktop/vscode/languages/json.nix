{pkgs, ...}: {
  programs.vscodium.profiles.default = {
    extensions = with pkgs.open-vsx; [
      blueglassblock.better-json5
    ];
    userSettings = {
      "[json]" = {
        "editor.defaultFormatter" = "oxc.oxc-vscode";
      };
    };
  };
}
