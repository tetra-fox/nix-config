{ inputs, ... }:

{
  imports = [ inputs.walker.homeManagerModules.default ];

  programs.walker = {
    enable = true;
    runAsService = true;

    config = {
      theme = "walkies";
    };

    themes = {
      "walkies" = {
        style = builtins.readFile ./theme/style.css;
      };
    };
  };
}
