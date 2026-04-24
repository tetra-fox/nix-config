{
  config,
  inputs,
  ...
}: let
  # stylix palette
  c = config.lib.stylix.colors.withHashtag;

  paletteVars = ''
    @define-color base         ${c.base00};
    @define-color mantle       ${c.base01};
    @define-color surface0     ${c.base02};
    @define-color surface1     ${c.base03};
    @define-color surface2     ${c.base04};
    @define-color text         ${c.base05};
    @define-color subtext0     ${c.base06};
    @define-color subtext1     ${c.base07};
    @define-color overlay0     ${c.base04};
    @define-color red          ${c.base08};
    @define-color accent       ${c.base0D};
  '';
in {
  imports = [inputs.walker.homeManagerModules.default];

  programs.walker = {
    enable = true;
    runAsService = true;

    config.theme = "walkies";

    themes.walkies.style = paletteVars + builtins.readFile ./theme/style.css;
  };

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
      # fixes missing icon for websearch provider (applications-internet)
      websearch = {
        settings = {
          icon = "web-browser";
        };
      };
    };
  };
}
