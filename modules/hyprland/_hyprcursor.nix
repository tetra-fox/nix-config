{pkgs, ...}: {
  home.pointerCursor = {
    name = "rose-pine-hyprcursor";
    hyprcursor = {
      enable = true;
      size = 26;
    };
    package = pkgs.rose-pine-hyprcursor;
  };

  home.packages = with pkgs; [
    hyprcursor
  ];
}
