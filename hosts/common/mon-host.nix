{
  config,
  lib,
  modules,
  ...
}: {
  imports = [modules.profiles.server.system];

  lab.monitoring = {
    server.enable = true;

    # proxmox nodes aren't nix hosts, so they come from the site facts instead of the flake
    extraScrapeConfigs =
      lib.mapAttrsToList (name: ip: {
        job_name = "node-${name}";
        static_configs = [{targets = ["${ip}:9100"];}];
      })
      config.lab.appliances.proxmoxNodes;

    # the lvm metrics come from a hand-installed prometheus-node-exporter-lvm.timer on each proxmox
    # node running debian's lvm-prom-collector -t. a full thin pool pauses every vm on the node
    alerts = [
      {
        name = "thin pool filling up";
        expr = "round(node_lvm_thin_pools_allocated, 0.1)";
        condition.value = 85;
        for = "15m";
        summary = "thin pool in vg {{ $labels.vgroup }} on {{ $labels.instance }} is {{ $values.B }}% allocated";
        labels.severity = "critical";
      }
      {
        name = "thin pool metadata filling up";
        expr = "round(node_lvm_thin_pools_metadata, 0.1)";
        condition.value = 80;
        for = "15m";
        summary = "thin pool metadata in vg {{ $labels.vgroup }} on {{ $labels.instance }} is {{ $values.B }}% used";
        labels.severity = "critical";
      }
      {
        # without this a dead collector timer makes the two rules above go quiet instead of firing
        name = "lvm metrics stale";
        expr = ''round((time() - node_textfile_mtime_seconds{file=~".*/lvm.prom"}) / 60)'';
        condition.value = 10;
        for = "0s";
        summary = "lvm.prom on {{ $labels.instance }} hasn't been rewritten in {{ $values.B }} minutes, check prometheus-node-exporter-lvm.timer";
        labels.severity = "warning";
      }
    ];
  };

  system.stateVersion = "26.11";
}
