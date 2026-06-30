{
  modules,
  ...
}: {
  imports = [
    modules.monitoring.system
    modules.logging.system
  ];

  # monitoring agent: node + systemd exporters + journal shipping to mon-01's loki.
  # unbound's query/error logs land in the journal; mon-01 auto-discovers this host.
  lab.logging.enable = true;
}
