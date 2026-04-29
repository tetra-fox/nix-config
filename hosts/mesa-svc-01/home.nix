{modules, ...}: {
  imports = [
    modules.profiles.server.home
  ];

  home.stateVersion = "26.05";
}
