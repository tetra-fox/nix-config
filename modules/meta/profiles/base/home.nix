# if i interface with it i want these things
{
  config,
  modules,
  ...
}: {
  imports = [
    modules.cli.zsh.home
    modules.cli.starship.home
  ];

  # propagate hm-managed env vars to systemd user units
  systemd.user.sessionVariables = config.home.sessionVariables;
}
