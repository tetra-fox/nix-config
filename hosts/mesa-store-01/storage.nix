# megamax is a raidz1 zpool over the four passthrough drives, created by hand
# (see modules/platform/zfs). datasets, not fileSystems entries: zfs mounts them
# itself from the pool, so there's nothing to declare here except the consumers.
#   megamax/media                  library/ + torrents/ + nzb/ as plain DIRS in one dataset:
#                                  sonarr/radarr hardlink from torrents to library on import,
#                                  and hardlinks can't cross a dataset boundary (recordsize=1M)
#   megamax/store                  general-purpose catch-all (snapshots on)
#   megamax/backup/homeassistant   gzipped HA backups pushed over NFS by the HAOS box
#   megamax/backup/timemachine     mac time machine target (samba, guest + mac-side encryption)
#   megamax/backup/postgres        postgres backups, wired up with the pgBackRest task (later)
#   megamax/immich                 immich photo library + inline db (immich task, later)
{
  config,
  lib,
  pkgs,
  modules,
  fleet,
  nixosConfigurations,
  ...
}: let
  siteData = config.lab.site.dataDir;
  topo = import fleet.topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };
  # the media host's internal-VLAN IP; the export + firewall scope to it.
  svcIp = topo.mediaHostIp;
  # the immich host's internal-VLAN IP; it NFS-mounts megamax/immich for the library.
  # null until a host advertises the immich capability, so the export/firewall/tmpfiles
  # for immich are all guarded on it being non-null.
  immichIp = topo.immichHostIp;
  # HAOS is multihomed; inter-VM traffic rides the internal VLAN exclusively (the server
  # VLAN is for inter-VLAN routing), so the export and firewall scope to its internal leg.
  # HAOS must mount this box's internal IP or its NFS source won't match. it connects as
  # root, so the export all_squashes root to admin:users. the backups are HAOS's private
  # blobs, deliberately NOT group media (not shared media content).
  haIp = "10.10.0.20";

  # the shared trees the nfs/samba consumers read+write. one list, reused by the tmpfiles
  # rules and the boot-time permission fixup below.
  sharedTrees = [
    "/mnt/megamax/media"
    "/mnt/megamax/store"
    "/mnt/megamax/backup/timemachine"
  ];

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
in {
  # the pool has no fileSystems entry (zfs mounts its own datasets), so nothing would
  # import it at boot without this. the pool name is host data, not a zfs-module default.
  boot.zfs.extraPools = ["megamax"];

  users.groups.media = {
    gid = 1002;
  };

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
      # immich library + its db-dump backups, owned by the pinned immich uid (990) so the
      # NFS export (numeric uids, no squash) lands writes as immich on this box. only when
      # a host advertises the immich capability.
      ++ lib.optionals (immichIp != null) [
        "d /mnt/megamax/immich 0700 990 990 -"
        "d /mnt/megamax/immich/library 0700 990 990 -"
        "d /mnt/megamax/immich/backups 0700 990 990 -"
      ];

    # boot-time safety net that re-asserts group ownership + setgid across the whole shared
    # trees, so a flubbed copy, a wrong-perms import, or a future mistake is fixed by a reboot
    # instead of nfs/samba throwing cryptic permission errors. deliberately fixes GROUP and
    # mode only, never the per-file user: the arr services legitimately own their own files
    # (sonarr writes as sonarr etc), and a chown -R to one user would rip that away every boot.
    # chgrp+chmod is enough because the share model is group-based (force group media, 2775).
    # runs after the mount and before the share daemons so they never start on a half-fixed tree.
    services.megamax-fix-perms = {
      description = "reassert group ownership + setgid on the megamax shared trees";
      wantedBy = ["multi-user.target"];
      before = ["nfs-server.service" "samba-smbd.service"];
      after = ["zfs-mount.service"];
      unitConfig.RequiresMountsFor = sharedTrees;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # chgrp to media, set setgid + group rwx on dirs and group rw on files, leave the
        # per-file user owner untouched. capital X so only dirs (and already-exec files) get +x.
        ExecStart = [
          "${pkgs.coreutils}/bin/chgrp -R media ${lib.escapeShellArgs sharedTrees}"
          "${pkgs.coreutils}/bin/chmod -R g+rwX ${lib.escapeShellArgs sharedTrees}"
          "${pkgs.findutils}/bin/find ${lib.escapeShellArgs sharedTrees} -type d -exec ${pkgs.coreutils}/bin/chmod g+s {} +"
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

  # two fsid=0 roots to different client IPs: the kernel keys the v4 pseudo-root per-client,
  # so each is an isolated namespace and neither client can traverse to the other. each
  # mounts `:/`. media keeps numeric uids (arr imports stay <svc-uid>:media); homeassistant
  # all_squashes to admin:users (1000:100) since HAOS connects as root, backups owned by admin
  # in admin's own group, kept out of group media on purpose. the media dataset is one
  # filesystem (library/torrents/nzb are dirs, not datasets), so a single export per client.
  lab.topology.provides = ["storage"];

  # immich mounts megamax/immich for its library + db-dump backups. numeric uids (no
  # squash): immich runs as uid 990 on svc-02 and the dirs are owned 990 here, so writes
  # line up. its own fsid=0 v4 root scoped to the immich host.
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
      "force group" = "media";
    };

    store = {
      path = "/mnt/megamax/store";
      browseable = "yes";
      "read only" = "no";
      "valid users" = "@users";
      "write list" = "@users";
      "create mask" = "0664";
      "directory mask" = "0775";
      "force group" = "media";
    };

    # time machine target. guest is acceptable ONLY because time machine encrypts the
    # sparsebundle mac-side before it lands here (tick "Encrypt Backups" on the mac),
    # so the nas holds ciphertext, same model as restic->b2. that encryption is a
    # mac-side toggle the nas can't enforce, so it is REQUIRED for guest to be safe.
    # when the authentik/ldap sso work lands, flip to authenticated (@users), drop guest.
    # global fruit hints (vfs objects, fruit:metadata) come from modules/services/samba.
    timemachine = {
      path = "/mnt/megamax/backup/timemachine";
      browseable = "yes";
      "read only" = "no";
      "guest ok" = "yes";
      "force user" = "admin";
      "force group" = "media";
      "create mask" = "0664";
      "directory mask" = "0775";
      "fruit:time machine" = "yes";
      "fruit:time machine max size" = "2T";
    };
  };
}
