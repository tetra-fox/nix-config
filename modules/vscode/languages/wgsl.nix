{pkgs, ...}: {
  programs.vscodium.profiles.default = {
    extensions = with pkgs.open-vsx; [
      wgsl-analyzer.wgsl-analyzer
    ];
    userSettings = {
      "wgsl-analyzer.server.path" = "${pkgs.wgsl-analyzer}/bin/wgsl-analyzer";
    };
  };
}
