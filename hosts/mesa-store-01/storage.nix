# megamax is a raidz1 zpool over the four passthrough drives, created by hand
# (see modules/platform/zfs). datasets, not fileSystems entries: zfs mounts them
# itself from the pool, so there's nothing to declare here except the consumers.
#   megamax/media          library/ + torrents/ + nzb/ as plain DIRS in one dataset:
#                          sonarr/radarr hardlink from torrents to library on import,
#                          and hardlinks can't cross a dataset boundary (recordsize=1M)
#   megamax/store          general-purpose catch-all (snapshots on)
#   megamax/homeassistant  gzipped HA backups (NFS only)
#   megamax/timemachine    mac time machine target (samba share added later)
{
  config,
  lib,
  pkgs,
  modules,
  fleet,
  siteData,
  nixosConfigurations,
  ...
}: let
  # the media host's internal-VLAN IP; the export + firewall scope to it.
  svcIp =
    (import fleet.topology {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }).mediaHostIp;
  # the HAOS box is an external appliance not on the internal VLAN, so it stays on the
  # server VLAN; it connects as root, so its export all_squashes root to admin:users. the
  # backups are HAOS's private blobs, deliberately NOT group media (not shared media content).
  haIp = "192.168.10.5";

  # the shared trees the nfs/samba consumers read+write. one list, reused by the tmpfiles
  # rules and the boot-time permission fixup below.
  sharedTrees = [
    "/mnt/megamax/media"
    "/mnt/megamax/store"
    "/mnt/megamax/timemachine"
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
  systemd.tmpfiles.rules = [
    "d ${siteData} 0755 root media -"
    "d /mnt/megamax/media/library 2775 admin media -"
    "d /mnt/megamax/media/torrents 2775 admin media -"
    "d /mnt/megamax/media/nzb 2775 admin media -"
    "d /mnt/megamax/store 2775 admin media -"
    "d /mnt/megamax/timemachine 2775 admin media -"
  ];

  # boot-time safety net that re-asserts group ownership + setgid across the whole shared
  # trees, so a flubbed copy, a wrong-perms import, or a future mistake is fixed by a reboot
  # instead of nfs/samba throwing cryptic permission errors. deliberately fixes GROUP and
  # mode only, never the per-file user: the arr services legitimately own their own files
  # (sonarr writes as sonarr etc), and a chown -R to one user would rip that away every boot.
  # chgrp+chmod is enough because the share model is group-based (force group media, 2775).
  # runs after the mount and before the share daemons so they never start on a half-fixed tree.
  systemd.services.megamax-fix-perms = {
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

  # two fsid=0 roots to different client IPs: the kernel keys the v4 pseudo-root per-client,
  # so each is an isolated namespace and neither client can traverse to the other. each
  # mounts `:/`. media keeps numeric uids (arr imports stay <svc-uid>:media); homeassistant
  # all_squashes to admin:users (1000:100) since HAOS connects as root, backups owned by admin
  # in admin's own group, kept out of group media on purpose. the media dataset is one
  # filesystem (library/torrents/nzb are dirs, not datasets), so a single export per client.
  lab.topology.provides = ["storage"];

  services.nfs.server = {
    enable = true;
    exports = ''
      /mnt/megamax/media ${svcIp}(rw,sync,no_subtree_check,fsid=0)
      /mnt/megamax/homeassistant ${haIp}(rw,sync,no_subtree_check,fsid=0,all_squash,anonuid=1000,anongid=100)
    '';
  };

  # source-scoped rules need the nftables backend (base profile enables it fleet-wide).
  networking.firewall.extraInputRules = ''
    ip saddr ${svcIp} tcp dport 2049 accept
    ip saddr ${haIp} tcp dport 2049 accept
  '';

  services.samba.settings = {
    global = {
      "server string" = "mesa";
      "fruit:model" = "MacPro7,1@ECOLOR=226,226,224"; # rack pro icon in Finder :3
    };

    media = {
      path = "/mnt/megamax/media";
      browseable = "yes";
      "read only" = "no";
      "guest ok" = "yes";
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
      "guest ok" = "yes";
      "valid users" = "@users";
      "write list" = "@users";
      "create mask" = "0664";
      "directory mask" = "0775";
      "force group" = "media";
    };
  };
}
