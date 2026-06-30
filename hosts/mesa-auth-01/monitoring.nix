{modules, ...}: {
  imports = [
    modules.monitoring.system
    modules.logging.system
  ];

  # monitoring AGENT: node + systemd exporters (site IP) + journal shipping to mon-01's
  # loki. the authentik containers run as podman-<name>.service, so their conmon output
  # lands in the journal and ships automatically. mon-01 auto-discovers this host.
  lab.logging.enable = true;
}
