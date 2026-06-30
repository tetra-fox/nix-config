{modules, ...}: {
  imports = [
    modules.services.monitoring.system
    modules.services.logging.system
  ];

  lab.logging.enable = true;
}
