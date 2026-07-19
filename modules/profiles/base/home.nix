{
  config,
  lib,
  modules,
  options,
  ...
}: {
  imports = [
    modules.cli.zsh.home
    modules.cli.starship.home
  ];

  config = lib.mkMerge [
    {home.stateVersion = lib.mkDefault "26.05";}
    # propagate hm-managed env vars to systemd user units. home-manager only
    # declares the systemd options on linux, so gate on the declaration (a
    # pkgs.stdenv guard would recurse: config's shape can't depend on pkgs)
    (lib.optionalAttrs (options ? systemd) {
      systemd.user.sessionVariables = config.home.sessionVariables;
    })
  ];
}
