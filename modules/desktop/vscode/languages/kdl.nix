{pkgs, ...}: {
  programs.vscodium.profiles.default = {
    extensions = with pkgs.open-vsx; [
      v1hz.kdl
    ];
    userSettings = {
      "kdl.command" = "${pkgs.kdl-lsp}/bin/kdl-lsp";
    };
  };
}
