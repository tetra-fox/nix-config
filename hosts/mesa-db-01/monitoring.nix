{
  modules,
  ...
}: {
  imports = [
    modules.monitoring.system
    modules.logging.system
  ];

  # monitoring AGENT: node + systemd exporters (bound to the site IP) + journal shipping
  # to mon-01's loki. mon-01 auto-discovers this host from the flake by its mesa-prefix +
  # declared IP. postgres logs to the journal, caught by the single journald source.
  lab.logging.enable = true;
}
