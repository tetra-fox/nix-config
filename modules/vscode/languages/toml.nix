{pkgs, ...}: {
  programs.vscodium.profiles.default = {
    extensions = with pkgs.open-vsx; [
      tamasfe.even-better-toml
    ];
    userSettings = {
      "evenBetterToml.taplo.bundled" = false;
      "evenBetterToml.taplo.path" = "${pkgs.taplo}/bin/taplo";
      "[toml]" = {
        "editor.defaultFormatter" = "tamasfe.even-better-toml";
      };
    };
  };
}
