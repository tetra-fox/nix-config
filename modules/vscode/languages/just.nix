{pkgs, ...}: {
  programs.vscodium.profiles.default = {
    extensions = with pkgs.open-vsx; [
      nefrob.vscode-just-syntax
    ];
  };
}
