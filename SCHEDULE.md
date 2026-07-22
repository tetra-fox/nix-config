# ⏰ schedule

## nightly

| utc         | pst   | pdt   | host(s)                            | job                                                                                          |
| ----------- | ----- | ----- | ---------------------------------- | -------------------------------------------------------------------------------------------- |
| 12:00       | 4:00a | 5:00a | mesa-svc-02                        | immich nightly tasks (db cleanup, face clustering, memories, missing thumbnails, quota sync) |
| 12:00       | 4:00a | 5:00a | mesa-svc-02                        | immich external library scan                                                                 |
| 12:00       | 4:00a | 5:00a | mesa-svc-01, fairlane-svc-01       | recyclarr sync (plus up to 5m random delay)                                                  |
| 12:00       | 4:00a | 5:00a | mesa-svc-01, fairlane-svc-01       | podman-auto-update: pulls and restarts containers labelled for auto-update                   |
| 12:00-13:00 | 4-5a  | 5-6a  | mesa-dns-01/02, fairlane-dns-01/02 | bind RPZ blocklist refresh + graceful reload (1h random spread)                              |
| 13:00       | 5:00a | 6:00a | mesa-svc-02                        | immich integrity checks (file checksums capped at 1h, missing files, untracked files)        |
| 14:00       | 6:00a | 7:00a | mesa-svc-02                        | immich pg_dumpall to megamax/immich/backups over nfs (minutes)                               |
| 14:00       | 6:00a | 7:00a | proxmox (external)                 | vzdump vm backup, configured in pve, not this repo                                           |
| 14:30       | 6:30a | 7:30a | mesa-store-01                      | restic to backblaze b2: zfs-snapshots each dataset, uploads, prunes                          |

the backup chain is the reason for the ordering: immich dumps its database next to the photo library at 14:00, restic snapshots megamax/immich at 14:30, so the offsite copy always carries a dump at most half an hour stale beside the exact library state it describes. everything else just needs to be off my evening.

## weekly (monday)

| utc   | pst   | pdt   | host(s)                                    | job                                             |
| ----- | ----- | ----- | ------------------------------------------ | ----------------------------------------------- |
| 12:00 | 4:00a | 5:00a | all nixos                                  | nix garbage collection                          |
| 13:00 | 5:00a | 6:00a | all nixos                                  | nix store optimise                              |
| 13:00 | 5:00a | 6:00a | mesa-svc-01, fairlane-svc-01, mesa-auth-01 | podman image prune                              |
| 14:00 | 6:00a | 7:00a | all nixos                                  | fstrim, after gc and optimise have freed blocks |

hara runs pacific local time, so its "Mon 12:00" lands monday noon; gc on an idle nvme is noise, and `persistent` catches up whenever the box happens to be on. myputer (also local time, launchd) does gc sunday 4a and optimise 5a.

## monthly

| utc        | pst   | pdt   | host(s)       | job                                                                                                                 |
| ---------- | ----- | ----- | ------------- | ------------------------------------------------------------------------------------------------------------------- |
| 1st, 12:00 | 4:00a | 5:00a | mesa-store-01 | zfs scrub of megamax. runs for hours at low io priority; overlaps that morning's restic run once a month, tolerable |

## left at defaults

- zfs auto-snapshots on mesa-store-01: hourly on the hour, daily/weekly/monthly at 00:00 UTC boundaries. snapshot creation is instant, so the 4p/5p pacific timestamp on the daily is cosmetic, and the nixos module doesn't expose per-tier calendars anyway
- prometheus scrapes (15s) and immich's ml healthcheck (30s) are continuous, not scheduled jobs

## external, not in this repo

- proxmox vzdump at 14:00: assuming the pve clock is UTC like everything else, that's 6a/7a pacific, already in the window. worth confirming in pve which vms it covers, where it writes, and that the target isn't a dataset restic reads at 14:30
- haos backups land in megamax/backup/homeassistant over nfs
  - > When the backup creation starts. By default Home Assistant picks the optimal time between 04:45 and 05:45.
  - aim it before 14:00 UTC so each restic run ships a fresh one
- time machine (myputer) writes megamax/backup/timemachine hourly while the mac is awake; restic snapshots whatever state is there at 14:30

## not backed up, on purpose

- fairlane-store-01: ext4 media store, contents re-downloadable, no restic. fairlane stays low-maintenance
- megamax/backup/postgres: TODO on mesa-store-01, add to restic's dataset list once db dumps land there
