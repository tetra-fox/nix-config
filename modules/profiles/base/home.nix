# universal home-manager base
# if i interface with it i want these things
{
  config,
  modules,
  ...
}: {
  imports = [
    modules.zsh.home
    modules.starship.home
  ];

  # propagate hm-managed env vars to systemd user units
  systemd.user.sessionVariables = config.home.sessionVariables;
}
