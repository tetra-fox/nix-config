# per-host sops secrets: backup/b2_env (B2_ACCOUNT_ID, B2_ACCOUNT_KEY) and
# backup/restic_password (the repo key, lose it and the backups are gone)
{
  config,
  lib,
  modules,
  ...
}: let
  cfg = config.lab.backup.restic;
  hn = config.networking.hostName;

  # one name across every dataset, so a run is a single point in time
  snapName = "restic-backup";

  snapshotPath = ds: "${ds.mountpoint}/.zfs/snapshot/${snapName}";

  zfs = "${config.boot.zfs.package}/bin/zfs";

  hasDatasets = cfg.datasets != [];
in {
  options.lab.backup.restic = {
    enable = lib.mkEnableOption "restic backup to backblaze b2";

    bucket = lib.mkOption {
      type = lib.types.str;
      description = ''
        backblaze b2 bucket name. the restic repository is b2:<bucket>:<hostname>,
        so one bucket can hold multiple hosts, each under its own path.
      '';
    };

    datasets = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "full zfs dataset name, e.g. megamax/store";
          };
          mountpoint = lib.mkOption {
            type = lib.types.str;
            description = "where the dataset is mounted, e.g. /mnt/megamax/store";
          };
        };
      });
      default = [];
      description = ''
        zfs datasets to back up. each is snapshotted atomically, then restic reads
        the frozen tree from <mountpoint>/.zfs/snapshot. use for zfs hosts; a host
        with no zfs uses paths instead.
      '';
    };

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        plain directories to back up live (no snapshot). for hosts without zfs.
        a file changing mid-run is captured torn. combine with datasets or use alone.
      '';
    };

    timerConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {
        # UTC, after the nightly db dumps, see SCHEDULE.md
        OnCalendar = "14:30";
        Persistent = true;
      };
      description = "systemd timer for the backup run. Persistent catches up a missed run after downtime.";
    };

    pruneOpts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
      ];
      description = "restic forget retention policy applied after each backup.";
    };
  };

  imports = [modules.services.monitoring.registry];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.datasets != [] || cfg.paths != [];
        message = "lab.backup.restic is enabled but neither datasets nor paths is set on host '${hn}'";
      }
    ];

    lab.monitoring.alerts = [
      {
        # also fires when the timer never ran. 26h gives a Persistent catch-up slack
        name = "restic backup stale";
        expr = ''round((time() - systemd_timer_last_trigger_seconds{name=~"restic-backups-.+"}) / 3600, 0.1)'';
        condition.value = 26;
        summary = "backup timer {{ $labels.name }} on {{ $labels.instance }} last fired {{ $values.B }}h ago";
        labels.severity = "critical";
      }
    ];

    sops.secrets."backup/b2_env" = {};
    sops.secrets."backup/restic_password" = {};

    services.restic.backups.b2 = {
      repository = "b2:${cfg.bucket}:${hn}";
      environmentFile = config.sops.secrets."backup/b2_env".path;
      passwordFile = config.sops.secrets."backup/restic_password".path;

      initialize = true;

      paths = (map snapshotPath cfg.datasets) ++ cfg.paths;

      inherit (cfg) pruneOpts timerConfig;

      # a paths-only host never references zfs
      backupPrepareCommand = lib.mkIf hasDatasets (lib.concatMapStringsSep "\n" (ds: ''
          ${zfs} destroy "${ds.name}@${snapName}" 2>/dev/null || true
          ${zfs} snapshot "${ds.name}@${snapName}"
        '')
        cfg.datasets);

      # runs whether the backup succeeded or failed
      backupCleanupCommand = lib.mkIf hasDatasets (lib.concatMapStringsSep "\n" (ds: ''
          ${zfs} destroy "${ds.name}@${snapName}" || true
        '')
        cfg.datasets);
    };
  };
}
