# megamax is a hand-created raidz1 pool, zfs mounts its datasets itself:
#   megamax/media                  library/ torrents/ nzb/ as dirs in ONE dataset, arr hardlinks can't cross datasets
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
  ...
}: let
  allowFrom = import fleet.nft {inherit lib;};
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
  ];

  # mount ordering only
  servedTrees = groupSharedTrees ++ ["/mnt/megamax/store" "/mnt/megamax/backup/timemachine"];

  # media is excluded on purpose, it's re-acquirable
  snapshotDatasets = [
    "megamax/store"
    "megamax/immich"
    "megamax/backup/homeassistant"
    "megamax/backup/timemachine"
    "megamax/backup/postgres"
  ];

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
    services.megamax-snapshot-policy = {
      description = "assert zfs auto-snapshot property on the megamax datasets";
      wantedBy = ["multi-user.target"];
      after = ["zfs-mount.service"];
      before = ["nfs-server.service" "samba-smbd.service"];
      unitConfig.RequiresMountsFor = ["/mnt/megamax/store"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart =
          map (ds: "${config.boot.zfs.package}/bin/zfs set com.sun:auto-snapshot=true ${ds}") snapshotDatasets;
      };
    };
  };

  lab.topology.provides = [caps.storage.name];

  # one fsid=0 root per client, only safe because each client is a single ip. a CIDR-scoped
  # export breaks that, export /mnt/megamax once with per-client subtrees instead.
  # homeassistant all_squashes because HAOS connects as root
  services.nfs.server = {
    enable = true;
    exports =
      ''
        /mnt/megamax/media ${svcIp}(rw,sync,no_subtree_check,fsid=0)
        /mnt/megamax/backup/homeassistant ${haIp}(rw,sync,no_subtree_check,fsid=0,all_squash,anonuid=1000,anongid=100)
      ''
      + lib.optionalString (immichIp != null) ''
        /mnt/megamax/immich ${immichIp}(rw,sync,no_subtree_check,fsid=0)
      ''
      # patroni's uid differs per node
      + lib.optionalString (dbIps != []) ''
        /mnt/megamax/backup/postgres ${lib.concatMapStringsSep " " (ip: "${ip}(rw,sync,no_subtree_check,fsid=0,all_squash,anonuid=1000,anongid=100)") dbIps}
      '';
  };

  networking.firewall.extraInputRules =
    allowFrom ([svcIp haIp] ++ lib.optional (immichIp != null) immichIp ++ dbIps) [2049];

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
