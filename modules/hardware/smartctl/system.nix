# smart health metrics for physical disks (smartctl_exporter). import on hosts that own
# real drives. auto-discovery queries every block device; ones without smart data (virtual
# disks) just produce no series. scanned scsi types fall back to auto, so sata drives
# behind virtio-scsi passthrough resolve to sat and report fine
{
  config,
  pkgs,
  modules,
  ...
}: {
  # options-only, registers the exporter without pulling in the monitoring stack
  imports = [modules.services.monitoring.registry];

  services.prometheus.exporters.smartctl = {
    enable = true;
    listenAddress = config.lab.monitoring.bindAddr;
  };

  lab.monitoring = {
    exporters = [
      {
        name = "smartctl";
        port = config.services.prometheus.exporters.smartctl.port;
      }
    ];

    dashboards = [pkgs.grafana-dashboards.smartctl-exporter-dashboard];

    alerts = [
      {
        name = "smart health failed";
        expr = "smartctl_device_smart_status == bool 0";
        summary = "disk {{ $labels.device }} on {{ $labels.instance }} failed its smart self-assessment";
        labels.severity = "critical";
      }
      {
        # nonzero raw counts here are the pre-failure signal for a dying drive,
        # usually long before the overall self-assessment flips
        name = "smart sector errors";
        expr = ''smartctl_device_attribute{attribute_name=~"Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable",attribute_value_type="raw"}'';
        summary = "disk {{ $labels.device }} on {{ $labels.instance }}: {{ $labels.attribute_name }} raw count {{ $values.B }}";
        labels.severity = "warning";
      }
      {
        name = "disk temperature high";
        expr = ''smartctl_device_temperature{temperature_type="current"}'';
        condition.value = 55;
        for = "30m";
        summary = "disk {{ $labels.device }} on {{ $labels.instance }} at {{ $values.B }}C";
        labels.severity = "warning";
      }
    ];
  };
}
