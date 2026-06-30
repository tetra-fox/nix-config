{pkgs, ...}: {
  programs.vscodium.profiles.default = {
    extensions = with pkgs.open-vsx; [
      nefrob.vscode-just-syntax
    ];
    userSettings = {
      "vscode-just.lspPath" = "${pkgs.just-lsp}/bin/just-lsp";
    };
  };
}
