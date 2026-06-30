{
  modules,
  ...
}: {
  imports = [
    modules.monitoring.system
    modules.logging.system
  ];

  lab.logging.enable = true;
}
