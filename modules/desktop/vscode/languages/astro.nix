{pkgs, ...}: {
  programs.vscodium.profiles.default.extensions = with pkgs.open-vsx; [
    astro-build.astro-vscode
  ];
}
