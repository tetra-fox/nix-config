{...}: {
  imports = [../_autostart.nix];

  my.autostart.targets = ["plasma-workspace.target"];
}
