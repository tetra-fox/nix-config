# restic -> backblaze b2. generic across hosts: import the module, drop in the
# credentials via sops, and set lab.backup.restic.{bucket,datasets,paths}.
#
# two ways to say what to back up, mix as needed:
#   datasets  zfs datasets. each is snapshotted under one shared name, restic
#             reads the frozen tree from <mount>/.zfs/snapshot/<name>, snapshot
#             destroyed after. consistent point-in-time, no torn files.
#   paths     plain directories, backed up live. for hosts with no zfs. a file
#             changing mid-run is captured torn, so use for mostly-static trees.
# at least one of the two must be non-empty.
#
# credentials (per consuming host, in that host's sops file):
#   backup/b2_env           B2_ACCOUNT_ID=... / B2_ACCOUNT_KEY=... (b2 app key)
#   backup/restic_password  the repo encryption password. lose it, lose the
#                           backups. keep a copy off-box (sops is that copy).
# the bucket name is plain config, not a secret. the repo is b2:<bucket>:<host>,
# so one bucket holds many hosts, each under its own path.
{
  config,
  lib,
  ...
}: let
  cfg = config.lab.backup.restic;
  hn = config.networking.hostName;

  # one snapshot name shared across every dataset in a run, so the whole set is a
  # single consistent moment.
  snapName = "restic-backup";

  # the .zfs/snapshot path restic reads for a given dataset mountpoint
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
        combine with datasets or use alone.
      '';
    };

    timerConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {
        OnCalendar = "02:30";
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

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.datasets != [] || cfg.paths != [];
        message = "lab.backup.restic is enabled but neither datasets nor paths is set on host '${hn}'";
      }
    ];

    # B2_ACCOUNT_ID / B2_ACCOUNT_KEY for the b2 backend, decrypted to a root-only
    # file, which is who the restic service runs as.
    sops.secrets."backup/b2_env" = {};
    # the restic repository password. losing it loses the backups.
    sops.secrets."backup/restic_password" = {};

    services.restic.backups.b2 = {
      repository = "b2:${cfg.bucket}:${hn}";
      environmentFile = config.sops.secrets."backup/b2_env".path;
      passwordFile = config.sops.secrets."backup/restic_password".path;

      # create the repo on first run if it doesn't exist yet
      initialize = true;

      paths = (map snapshotPath cfg.datasets) ++ cfg.paths;

      inherit (cfg) pruneOpts timerConfig;

      # snapshot machinery only when there are datasets. a non-zfs host (paths
      # only) never references zfs, so the module stays importable without it.
      backupPrepareCommand = lib.mkIf hasDatasets (lib.concatMapStringsSep "\n" (ds: ''
          ${zfs} destroy "${ds.name}@${snapName}" 2>/dev/null || true
          ${zfs} snapshot "${ds.name}@${snapName}"
        '')
        cfg.datasets);

      # tear the snapshots down whether the run succeeded or failed
      backupCleanupCommand = lib.mkIf hasDatasets (lib.concatMapStringsSep "\n" (ds: ''
          ${zfs} destroy "${ds.name}@${snapName}" || true
        '')
        cfg.datasets);
    };
  };
}
