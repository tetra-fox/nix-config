{
  config,
  lib,
  modules,
  ...
}: {
  imports = [
    modules.cli.zsh.home
    modules.cli.starship.home
  ];

  home.stateVersion = lib.mkDefault "26.05";

  # propagate hm-managed env vars to systemd user units
  systemd.user.sessionVariables = config.home.sessionVariables;
}
