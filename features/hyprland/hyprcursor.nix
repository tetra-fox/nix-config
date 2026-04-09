{ pkgs, ... }:

{
  home.pointerCursor = {
    name = "rose-pine-hyprcursor";
    hyprcursor = {
      enable = true;
      size = 24;
    };
    package = pkgs.rose-pine-hyprcursor;
  };

  home.packages = with pkgs; [
    hyprcursor
  ];
}
