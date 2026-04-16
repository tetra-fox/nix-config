{ pkgs, ... }:

{
  home.pointerCursor = {
    name = "rose-pine-hyprcursor";
    hyprcursor = {
      enable = true;
      size = 32;
    };
    package = pkgs.rose-pine-hyprcursor;
  };

  home.packages = with pkgs; [
    hyprcursor
  ];
}
