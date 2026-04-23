{inputs, ...}: {
  imports = [inputs.walker.homeManagerModules.default];

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

  # fixes missing icon for websearch provider (applications-internet)
  programs.elephant = {
    provider = {
      "1password" = {
        settings = {
          vaults = [
            "Private"
            "mesa"
            "fairlane"
            "furryconvention2005"
          ];
        };
      };
      websearch = {
        settings = {
          icon = "web-browser";
        };
      };
    };
  };
}
