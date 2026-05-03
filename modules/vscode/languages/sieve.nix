{pkgs, ...}: {
  programs.vscode.profiles.default.extensions = with pkgs.open-vsx; [
    adzero.vscode-sievehighlight
  ];
}
