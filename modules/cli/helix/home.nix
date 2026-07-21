{
  pkgs,
  osConfig,
  fleet,
  ...
}: {
  programs.helix = {
    enable = true;

    defaultEditor = true;

    # helix's built-in languages.toml assumes `nixd` is on PATH; point at the store path
    # directly instead, matching how the vscode module resolves it (see nix.nix)
    languages.language-server.nixd = {
      command = "${pkgs.nixd}/bin/nixd";
      config = import fleet.nixd-settings {inherit pkgs osConfig;};
    };

    settings = {
      editor = {
        bufferline = "always";
        line-number = "relative";
        cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };
      };
      keys.normal = {
        tab = ":bn";
        S-tab = ":bp";
      };
    };
  };
}
