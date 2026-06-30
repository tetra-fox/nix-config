{pkgs, ...}: {
  programs.vscodium.profiles.default.extensions = with pkgs.open-vsx; [
    adzero.vscode-sievehighlight
  ];
}
