{modules, ...}: {
  imports = [
    modules.monitoring.system
    modules.logging.system
  ];

  # monitoring AGENT: runs node + systemd exporters (bound to the site IP, since mesa is
  # multi-host) and ships its journal to mon-01's loki. mon-01 auto-discovers this host
  # from the flake by its mesa-prefix + declared IP -- no scrape config to maintain.
  # no fileSources: store-01's services (nfs, smbd) log to the journal, which the single
  # journald source already catches.
  lab.logging.enable = true;
}
