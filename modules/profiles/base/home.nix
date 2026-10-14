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
    # hm only declares systemd options on linux. a pkgs.stdenv guard would infinitely
    # recurse, config's shape can't depend on pkgs
    (lib.optionalAttrs (options ? systemd) {
      systemd.user.sessionVariables = config.home.sessionVariables;
    })
  ];
}
