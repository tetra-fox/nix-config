{modules, ...}: {
  imports = [
    modules.meta.profiles.server.home
  ];

  home.stateVersion = "26.05";
}
