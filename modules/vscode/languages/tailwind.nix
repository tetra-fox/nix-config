{pkgs, ...}: {
  programs.vscode.profiles.default.extensions = with pkgs.open-vsx; [
    bradlc.vscode-tailwindcss
  ];
}
