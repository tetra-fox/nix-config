# if i interface with it i want these things
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

  # the home-manager state version. lives here (the shared home root) so a host that gets its
  # home config from a profile -- not a per-host home.nix -- still has it. mkDefault lets a
  # host pin a different version. servers track the server stateVersion; hara overrides.
  home.stateVersion = lib.mkDefault "26.05";

  # propagate hm-managed env vars to systemd user units
  systemd.user.sessionVariables = config.home.sessionVariables;
}
