{pkgs, ...}: {
  programs.vscodium.profiles.default.extensions = with pkgs.open-vsx; [
    bradlc.vscode-tailwindcss
  ];
}
