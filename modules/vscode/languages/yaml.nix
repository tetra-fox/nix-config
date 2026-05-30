{pkgs, ...}: {
  programs.vscodium.profiles.default = {
    extensions = with pkgs.open-vsx; [
      jimeh.actionlint
    ];
    userSettings = {
      "actionlint.executable" = "${pkgs.actionlint}/bin/actionlint";
      "[yaml]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
    };
  };
}
