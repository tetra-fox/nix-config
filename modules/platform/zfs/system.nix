# zfs as a filesystem type. this also puts zpool/zfs in PATH, version-locked
# to the kernel module, which is why they're not in the disk toolset
{
  config,
  lib,
  pkgs,
  modules,
  ...
}: {
  # options-only, registers the zfs exporter without pulling in the monitoring stack
  imports = [modules.services.monitoring.registry];

  boot.supportedFilesystems = ["zfs"];

  # zfs needs a compatible kernel. pin it to the latest LTS
  # TODO: bump when we get a new `longterm`: https://kernel.org/
  boot.kernelPackages = pkgs.linuxPackages_6_18;

  # zfs refuses to import a pool last touched by a different hostid; derive a
  # stable unique one from the hostname instead of hand-picking hex per host
  networking.hostId = lib.mkDefault (builtins.substring 0 8 (builtins.hashString "sha256" config.networking.hostName));

  # pool health/capacity metrics (pdf/zfs_exporter). node exporter's zfs collector only
  # covers arc/kstat internals, not pool state or capacity
  services.prometheus.exporters.zfs = {
    enable = true;
    listenAddress = config.lab.monitoring.bindAddr;
  };

  lab.monitoring = {
    exporters = [
      {
        name = "zfs";
        port = config.services.prometheus.exporters.zfs.port;
      }
    ];

    dashboards = [pkgs.grafana-dashboards.zfs-pool-performance-and-health];

    alerts = [
      {
        # health codes: 0 online, 1 degraded, 2 faulted, 3 offline, 4 unavail, 5 removed, 6 suspended
        name = "zfs pool unhealthy";
        expr = "zfs_pool_health";
        for = "2m";
        summary = "pool {{ $labels.pool }} on {{ $labels.instance }} is not ONLINE (health code {{ $values.B }})";
        labels.severity = "critical";
      }
      {
        # past ~85% zfs allocation slows down and fragmentation compounds
        name = "zfs pool capacity high";
        expr = "100 * zfs_pool_capacity_ratio";
        condition.value = 85;
        for = "1h";
        summary = "pool {{ $labels.pool }} on {{ $labels.instance }} is {{ $values.B }}% full";
        labels.severity = "warning";
      }
    ];
  };

  services.zfs = {
    # weekly default is a lot of thrash on multi-TB spinning pools
    autoScrub = {
      enable = true;
      # monthly on the 1st. servers are UTC, 12:00 is 4a/5a pacific
      # see SCHEDULE.md
      interval = "*-*-01 12:00:00";
    };

    # only snapshots datasets with com.sun:auto-snapshot=true set, so this is
    # opt-in per dataset, not a blanket snapshot of the whole pool. frequent
    # off: 15-minute snapshots are churn we don't want on a media store
    autoSnapshot = {
      enable = true;
      frequent = 0;
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 6;
    };
  };
}
