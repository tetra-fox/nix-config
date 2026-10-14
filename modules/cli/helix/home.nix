{
  pkgs,
  osConfig,
  fleet,
  ...
}: {
  programs.helix = {
    enable = true;

    defaultEditor = true;

    # helix's built-in languages.toml expects nixd on PATH
    languages.language-server.nixd = {
      command = "${pkgs.nixd}/bin/nixd";
      config = fleet.nixd-settings {inherit pkgs osConfig;};
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
