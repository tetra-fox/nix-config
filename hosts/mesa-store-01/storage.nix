# megamax is a raidz1 zpool over the four passthrough drives, created by hand
# (see modules/platform/zfs). datasets, not fileSystems entries: zfs mounts them
# itself from the pool, so there's nothing to declare here except the consumers.
#   megamax/media                  library/ + torrents/ + nzb/ as plain DIRS in one dataset:
#                                  sonarr/radarr hardlink from torrents to library on import,
#                                  and hardlinks can't cross a dataset boundary (recordsize=1M)
#   megamax/store                  general-purpose catch-all, per-user %U subdirs (snapshots on)
#   megamax/backup/homeassistant   gzipped HA backups pushed over NFS by the HAOS box
#   megamax/backup/timemachine     mac time machine target, per-user %U subdirs (samba, authenticated)
#   megamax/backup/postgres        postgres backups, wired up with the pgBackRest task (later)
#   megamax/immich                 immich photo library + inline db (immich task, later)
{
  config,
  lib,
  pkgs,
  modules,
  topo,
  caps,
  ...
}: let
  siteData = config.lab.site.dataDir;
  # the media host's internal-VLAN IP; the export + firewall scope to it.
  svcIp = topo.mediaHostIp;
  # the immich host's internal-VLAN IP; it NFS-mounts megamax/immich for the library.
  # null until a host advertises the immich capability, so the export/firewall/tmpfiles
  # for immich are all guarded on it being non-null.
  immichIp = topo.immichHostIp;
  # haosIp is HAOS's internal-VLAN leg (see the site facts), so the export and firewall
  # scope to inter-VM traffic. HAOS must mount this box's internal IP or its NFS source
  # won't match. it connects as root, so the export all_squashes root to admin:users. the
  # backups are HAOS's private blobs, deliberately NOT group media (not shared media content).
  haIp = config.lab.appliances.haosIp;

  # media is the one tree that's genuinely group-shared (arr services + every samba user
  # co-write into it), so it's the only one the boot-time recursive reconciler below touches.
  # store/timemachine now serve per-user %U subdirs (owner-only, 0700, no group grant), which
  # a recursive chgrp/chmod would fight every boot -- reconciling those is samba's own
  # "root preexec" job per connection, not a fleet-wide sweep.
  groupSharedTrees = [
    "/mnt/megamax/media"
  ];

  # every tree a share serves, mount-ordering only (no group-reconciliation implication) --
  # samba/nfs must wait for all of these to actually be mounted before starting.
  servedTrees = groupSharedTrees ++ ["/mnt/megamax/store" "/mnt/megamax/backup/timemachine"];

  # datasets that get local zfs auto-snapshots (the zfs module runs zfs-auto-snapshot on
  # com.sun:auto-snapshot=true, opt-in per dataset). media is excluded on purpose: 808G of
  # re-acquirable content, not worth the snapshot metadata. the property is asserted at boot
  # by the oneshot below so it's declared here, not hand-set drift on the pool.
  snapshotDatasets = [
    "megamax/store"
    "megamax/immich" # library + immich's own db dumps; local history for oops-recovery
    "megamax/backup/homeassistant" # HA backup tarballs
    "megamax/backup/timemachine" # time machine image
  ];

  # samba's account registry is Linux users (valid users = @users on the media/store shares):
  # samba needs a Linux user to exist to map uid/gid, but these people never actually log into
  # this box, so no password, no shell, no home dir. the samba side (the actual secret) is set
  # once per person with `smbpasswd -a <user>`, run manually over ssh -- never declared here,
  # so it's never a plaintext-at-rest secret sitting in the repo or decrypted to disk at every
  # activation for what amounts to a handful of household accounts.
  sambaUsers = ["tetra" "melody" "riley"];
in {
  # the pool has no fileSystems entry (zfs mounts its own datasets), so nothing would
  # import it at boot without this. the pool name is host data, not a zfs-module default.
  boot.zfs.extraPools = ["megamax"];

  users.groups.${config.lab.media.group}.gid = config.lab.media.gid;

  users.users = lib.genAttrs sambaUsers (name: {
    isSystemUser = true;
    group = config.lab.media.group;
    extraGroups = ["users"];
    shell = "${pkgs.shadow}/bin/nologin";
  });

  # these run after zfs-mount (zfs-mount is Before=local-fs.target, tmpfiles is After),
  # so the datasets are mounted when these fire. `d` not `Z`: create the dir and set its
  # own mode/owner, but do NOT recurse, service-written files under here keep their own
  # ownership and we don't re-walk the whole library every activation. setgid so new files
  # inherit group media, letting the service uids and SMB @users share write. the arrs
  # hardlink media/torrents -> media/library, which needs them in the same dataset.
  systemd = {
    tmpfiles.rules =
      [
        "d ${siteData} 0755 root media -"
        "d /mnt/megamax/media/library 2775 admin media -"
        "d /mnt/megamax/media/torrents 2775 admin media -"
        "d /mnt/megamax/media/nzb 2775 admin media -"
        "d /mnt/megamax/store 2775 admin media -"
        "d /mnt/megamax/backup/timemachine 2775 admin media -"
        # HA backups: owned admin:users to match the NFS all_squash (anonuid=1000
        # anongid=100), 0700, deliberately not group media and no setgid
        "d /mnt/megamax/backup/homeassistant 0700 admin users -"
      ]
      # immich library + its db-dump backups, owned by the immich host's pinned uid so the
      # NFS export (numeric uids, no squash) lands writes as immich on this box. only when
      # a host advertises the immich capability.
      ++ lib.optionals (immichIp != null) (let
        uid = toString topo.immichUid;
      in [
        "d /mnt/megamax/immich 0700 ${uid} ${uid} -"
        "d /mnt/megamax/immich/library 0700 ${uid} ${uid} -"
        "d /mnt/megamax/immich/backups 0700 ${uid} ${uid} -"
      ]);

    # boot-time safety net that re-asserts group ownership + setgid across the group-shared
    # trees (media only -- see groupSharedTrees), so a flubbed copy, a wrong-perms import, or a
    # future mistake is fixed by a reboot instead of nfs/samba throwing cryptic permission
    # errors. deliberately fixes GROUP and mode only, never the per-file user: the arr services
    # legitimately own their own files (sonarr writes as sonarr etc), and a chown -R to one
    # user would rip that away every boot. chgrp+chmod is enough because the share model is
    # group-based (force group media, 2775). runs after the mount and before the share daemons
    # so they never start on a half-fixed tree. RequiresMountsFor covers every served tree
    # (including store/timemachine), even though this unit only rewrites media's permissions --
    # it still needs store/timemachine mounted before samba starts.
    services.megamax-fix-perms = {
      description = "reassert group ownership + setgid on the megamax group-shared trees";
      wantedBy = ["multi-user.target"];
      before = ["nfs-server.service" "samba-smbd.service"];
      after = ["zfs-mount.service"];
      unitConfig.RequiresMountsFor = servedTrees;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # chgrp to media, set setgid + group rwx on dirs and group rw on files, leave the
        # per-file user owner untouched. capital X so only dirs (and already-exec files) get +x.
        ExecStart = [
          "${pkgs.coreutils}/bin/chgrp -R media ${lib.escapeShellArgs groupSharedTrees}"
          "${pkgs.coreutils}/bin/chmod -R g+rwX ${lib.escapeShellArgs groupSharedTrees}"
          "${pkgs.findutils}/bin/find ${lib.escapeShellArgs groupSharedTrees} -type d -exec ${pkgs.coreutils}/bin/chmod g+s {} +"
        ];
      };
    };

    # assert com.sun:auto-snapshot=true on the datasets we want local snapshot history for,
    # so the policy lives in this config next to the datasets instead of being hand-set on the
    # pool. zfs set is idempotent (no-op if already set). runs in normal multi-user space after
    # the pool is mounted -- NOT before zfs-mount, which pulls it into the early-boot ordering
    # knot (zfs-mount -> local-fs -> sysinit -> basic.target) and creates a cycle that systemd
    # breaks by dropping random critical units like sshd.socket. it only needs the pool mounted,
    # which zfs-mount + RequiresMountsFor guarantee, so ordering after that is enough.
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

  # three fsid=0 roots below, one per client. this is unusual -- nfsd normally has a single
  # pseudo-root -- but it's safe as long as every fsid=0 export's client specifier is a single
  # host address with no overlap between them: nfsd resolves a client's `:/` mount against
  # whichever export line matches its source address, so disjoint single-IP scopes can never
  # collide. that's structural here, not just true today: mediaHostIp/immichHostIp come from
  # the capability engine's single-provider lookup, which throws rather than silently returning
  # an ambiguous IP if two hosts ever advertised the same capability, and haIp is a literal
  # address, not a range. if this ever grows a CIDR-scoped export instead of a single IP, that
  # invariant breaks and overlapping clients would see "access denied" or the wrong root -- the
  # cleaner alternative at that point is one export of the whole /mnt/megamax pseudo-root with
  # per-client subtree permissions, not more fsid=0 lines.
  # media keeps numeric uids (arr imports stay <svc-uid>:media); homeassistant all_squashes to
  # admin:users (1000:100) since HAOS connects as root, backups owned by admin in admin's own
  # group, kept out of group media on purpose. the media dataset is one filesystem
  # (library/torrents/nzb are dirs, not datasets), so a single export per client.
  lab.topology.provides = [caps.storage.name];

  # immich mounts megamax/immich for its library + db-dump backups. numeric uids (no
  # squash): the dirs here are owned by the immich host's pinned uid, so writes line up.
  # its own fsid=0 v4 root scoped to the immich host.
  services.nfs.server = {
    enable = true;
    exports =
      ''
        /mnt/megamax/media ${svcIp}(rw,sync,no_subtree_check,fsid=0)
        /mnt/megamax/backup/homeassistant ${haIp}(rw,sync,no_subtree_check,fsid=0,all_squash,anonuid=1000,anongid=100)
      ''
      + lib.optionalString (immichIp != null) ''
        /mnt/megamax/immich ${immichIp}(rw,sync,no_subtree_check,fsid=0)
      '';
  };

  # source-scoped rules need the nftables backend (base profile enables it fleet-wide).
  networking.firewall.extraInputRules =
    ''
      ip saddr ${svcIp} tcp dport 2049 accept
      ip saddr ${haIp} tcp dport 2049 accept
    ''
    + lib.optionalString (immichIp != null) ''
      ip saddr ${immichIp} tcp dport 2049 accept
    '';

  services.samba.settings = {
    global = {
      "fruit:model" = "MacPro7,1@ECOLOR=226,226,224"; # rack pro icon in Finder :3
    };

    # no "guest ok": valid users already forecloses the guest fallback, so it was dead config
    # that misleadingly read as a guest share when it's actually authenticated-only.
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

    # %U -> per-user private subdir (0700, owner-only). root preexec creates it since samba
    # doesn't; wrapped in sh -c because samba execs preexec directly, no shell.
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

    # same %U/root preexec pattern as store. mac-side "Encrypt Backups" is still recommended,
    # just not load-bearing now that this is authenticated rather than guest.
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
