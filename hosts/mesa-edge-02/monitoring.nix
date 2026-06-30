{modules, ...}: {
  imports = [
    modules.monitoring.system
    modules.logging.system
  ];

  # monitoring AGENT: node + systemd exporters (site IP) + journal shipping to mon-01's
  # loki. caddy's access log + fail2ban + keepalived land in the journal. mon-01 auto-discovers.
  lab.logging.enable = true;
}
