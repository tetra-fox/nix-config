# megamax is a hand-created raidz1 pool, zfs mounts its datasets itself:
#   megamax/media                  library/ torrents/ nzb/ slskd/ as dirs in ONE dataset, arr hardlinks can't cross datasets
#   megamax/music                  hand-curated library, edited over samba, read by services over NFS
#   megamax/store                  per-user %U subdirs
#   megamax/backup/homeassistant   HA backups pushed over NFS by HAOS
#   megamax/backup/timemachine     per-user %U subdirs
#   megamax/backup/postgres        pg_dumpall pushed over NFS by the db leader
#   megamax/immich                 immich library + db dumps
{
  config,
  lib,
  pkgs,
  fleet,
  topo,
  caps,
  username,
  ...
}: let
  svcIp = topo.mediaHostIp;
  # null until a host advertises the immich capability
  immichIp = topo.immichHostIp;
  # HAOS's internal-VLAN leg, so HAOS must mount this box's internal IP
  haIp = config.lab.appliances.haosIp;
  # any node can be the leader, so all are admitted
  dbIps = topo.dbHaNodeIps;

  # store/timemachine are per-user 0700 subdirs owned via samba root preexec, a recursive
  # chgrp would fight that
  groupSharedTrees = [
    "/mnt/megamax/media"
    "/mnt/megamax/music"
  ];

  # mount ordering only
  servedTrees = groupSharedTrees ++ ["/mnt/megamax/store" "/mnt/megamax/backup/timemachine"];

  # zfs snapshots and the b2 backup. media is excluded on purpose, it's re-acquirable. a
  # snapshot of megamax/backup doesn't capture its child datasets, so each is listed
  protectedDatasets =
    map (name: {
      inherit name;
      mountpoint = "/mnt/${name}";
    }) [
      "megamax/store"
      "megamax/music"
      "megamax/immich"
      "megamax/backup/homeassistant"
      "megamax/backup/timemachine"
      "megamax/backup/postgres"
    ];

  # on top of the pool's zstd, atime=off, xattr=sa. recordsize only applies to new writes
  datasetProperties = {
    # large audio files read start to finish
    "megamax/music".recordsize = "1M";
  };

  nfs = fleet.nfs-exports "/mnt/megamax" {
    media = {
      ips = [svcIp];
      options = "rw,sync,no_subtree_check";
    };
    # services only read the library, writes go through samba
    music = {
      ips = [svcIp];
      options = "ro,sync,no_subtree_check";
    };
    immich = {
      ips = lib.optional (immichIp != null) immichIp;
      options = "rw,sync,no_subtree_check";
    };
    # HAOS connects as root, and patroni's uid differs per node
    "backup/homeassistant" = {
      ips = [haIp];
      options = "rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=100";
    };
    "backup/postgres" = {
      ips = dbIps;
      options = "rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=100";
    };
  };

  # samba needs a linux user to map uids, no login. the samba password is set by hand with
  # `smbpasswd -a <user>` so it never lives in the repo
  sambaUsers = ["tetra" "melody" "riley"];
in {
  boot.zfs.extraPools = ["megamax"];

  users.groups.${config.lab.media.group}.gid = config.lab.media.gid;
  lab.site.dataDirGroup = config.lab.media.group;

  users.users = lib.genAttrs sambaUsers (_name: {
    isSystemUser = true;
    group = config.lab.media.group;
    extraGroups = ["users"];
  });

  # `d` not `Z`: don't recurse, service-written files keep their owner.
  # setgid so new files inherit group media
  systemd = {
    tmpfiles.rules =
      [
        "d /mnt/megamax/media/library 2775 admin media -"
        "d /mnt/megamax/media/torrents 2775 admin media -"
        "d /mnt/megamax/media/nzb 2775 admin media -"
        "d /mnt/megamax/media/slskd 2775 admin media -"
        "d /mnt/megamax/media/slskd/downloads 2775 admin media -"
        "d /mnt/megamax/media/slskd/incomplete 2775 admin media -"
        "d /mnt/megamax/music 2775 admin media -"
        "d /mnt/megamax/store 2775 admin media -"
        "d /mnt/megamax/backup/timemachine 2775 admin media -"
        # admin:users matches the NFS all_squash anonuid/anongid
        "d /mnt/megamax/backup/homeassistant 0700 admin users -"
        "d /mnt/megamax/backup/postgres 0700 admin users -"
      ]
      # owned by the immich host's pinned uid, the export doesn't squash
      ++ lib.optionals (immichIp != null) (let
        uid = toString topo.immichUid;
      in [
        "d /mnt/megamax/immich 0700 ${uid} ${uid} -"
        "d /mnt/megamax/immich/library 0700 ${uid} ${uid} -"
        "d /mnt/megamax/immich/backups 0700 ${uid} ${uid} -"
      ]);

    # group and mode only, never chown: the arrs own their files
    services.megamax-fix-perms = {
      description = "reassert group ownership + setgid on the megamax group-shared trees";
      wantedBy = ["multi-user.target"];
      before = ["nfs-server.service" "samba-smbd.service"];
      after = ["zfs-mount.service"];
      unitConfig.RequiresMountsFor = servedTrees;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = [
          "${pkgs.coreutils}/bin/chgrp -R media ${lib.escapeShellArgs groupSharedTrees}"
          "${pkgs.coreutils}/bin/chmod -R g+rwX ${lib.escapeShellArgs groupSharedTrees}"
          "${pkgs.findutils}/bin/find ${lib.escapeShellArgs groupSharedTrees} -type d -exec ${pkgs.coreutils}/bin/chmod g+s {} +"
        ];
      };
    };

    # runs after the pool mounts, NOT before zfs-mount. otherwise random shit breaks and sshd dies
    services.megamax-dataset-properties = {
      description = "assert zfs properties on the megamax datasets";
      wantedBy = ["multi-user.target"];
      after = ["zfs-mount.service"];
      before = ["nfs-server.service" "samba-smbd.service"];
      unitConfig.RequiresMountsFor = ["/mnt/megamax/store"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let
          zfsSet = ds: prop: value: "${config.boot.zfs.package}/bin/zfs set ${prop}=${value} ${ds}";
        in
          map (ds: zfsSet ds.name "com.sun:auto-snapshot" "true") protectedDatasets
          ++ lib.concatLists (lib.mapAttrsToList (ds: lib.mapAttrsToList (zfsSet ds)) datasetProperties);
      };
    };
  };

  lab.topology.provides = [caps.storage.name];

  lab.backup.restic.datasets = protectedDatasets;

  services.nfs.server = {
    enable = true;
    inherit (nfs) exports;
  };

  networking.firewall.extraInputRules = fleet.allow-from nfs.ips [2049];

  services.samba.settings = {
    global = {
      "fruit:model" = "MacPro7,1@ECOLOR=226,226,224"; # rack pro icon in finder
    };

    media = {
      path = "/mnt/megamax/media";
      browseable = "yes";
      "read only" = "no";
      "valid users" = "@users";
      "write list" = "@users";
      "create mask" = "0664";
      "directory mask" = "0775";
      "force group" = config.lab.media.group;
    };

    # the library you curate. group media and group-readable so services can read what you add
    music = {
      path = "/mnt/megamax/music";
      browseable = "yes";
      "read only" = "no";
      "valid users" = "@users";
      "write list" = username;
      "create mask" = "0664";
      "directory mask" = "0775";
      "force group" = config.lab.media.group;
      # finder litter, it would also end up shared on soulseek
      "veto files" = "/.DS_Store/._*/Thumbs.db/";
      "delete veto files" = "yes";
    };

    # per-user private subdir
    store = {
      path = "/mnt/megamax/store/%U";
      browseable = "yes";
      "read only" = "no";
      "valid users" = "@users";
      "write list" = "@users";
      "create mask" = "0600";
      "directory mask" = "0700";
      "root preexec" = "${pkgs.bash}/bin/sh -c '${pkgs.coreutils}/bin/mkdir -p -m 0700 /mnt/megamax/store/%U && ${pkgs.coreutils}/bin/chown %U /mnt/megamax/store/%U'";
    };

    timemachine = {
      path = "/mnt/megamax/backup/timemachine/%U";
      browseable = "no";
      "read only" = "no";
      "valid users" = "@users";
      "write list" = "@users";
      "root preexec" = "${pkgs.bash}/bin/sh -c '${pkgs.coreutils}/bin/mkdir -p -m 0700 /mnt/megamax/backup/timemachine/%U && ${pkgs.coreutils}/bin/chown %U /mnt/megamax/backup/timemachine/%U'";
      "create mask" = "0600";
      "directory mask" = "0700";
      "fruit:time machine" = "yes";
      "fruit:time machine max size" = "2T";
    };
  };
}
