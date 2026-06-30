{...}: {
  programs.helix = {
    enable = true;

    defaultEditor = true;

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
