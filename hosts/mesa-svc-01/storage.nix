# svc-01 is now an NFS CLIENT of mesa-store-01: the media disk + samba shares moved to
# the storage tier (Phase 1). this box mounts the shared library over NFS and keeps
# running the arrs + qbit/sab, which write into it as their pinned uids (Phase 0a) so
# files land <svc-uid>:media, not nobody.
#
# /mnt/vol_1/milkfish        the shared library, now NFS-mounted from store-01
# /var/lib/mesa/<service>    local state for every native + container service
# siteData (/var/lib/mesa) comes from the `mesa` site tag (modules/sites/mesa.nix)
{siteData, ...}: let
  storeIp = "10.10.0.222"; # store-01 over the isolated internal VLAN (east-west NFS)
in {
  # the media group's gid must match store-01 (1002): NFS squashes on the numeric gid,
  # so a mismatch would make group-write fail. the arr-stack also declares this group
  # (without a gid); this is where the gid is pinned.
  users.groups.media = {
    gid = 1002;
  };

  systemd.tmpfiles.rules = [
    "d ${siteData} 0755 root media -"
  ];

  # mount the library over NFSv4 from store-01. milkfish is its own fsid=0 v4 root
  # scoped to svc-01, so the client mounts `:/` (svc-01 can't even see store-01's other
  # shares -- separate per-client namespaces). automount + idle-timeout so the mount
  # comes up on first access and a store-01 reboot doesn't wedge svc-01; nofail keeps
  # boot non-blocking. jumbo MTU 9000 is already set site-wide (modules/sites/mesa.nix).
  fileSystems."/mnt/vol_1/milkfish" = {
    device = "${storeIp}:/";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "_netdev"
    ];
  };

  # the media services read/write the library, so they must wait for the (auto)mount
  # rather than racing it and operating on the empty mountpoint underneath. each gets
  # RequiresMountsFor on the library path, which blocks the unit until the automount
  # has pulled the share up. listed explicitly: these are the units that touch it.
  systemd.services = builtins.listToAttrs (map (name: {
    inherit name;
    value.unitConfig.RequiresMountsFor = ["/mnt/vol_1/milkfish"];
  }) ["sonarr" "radarr" "jellyfin" "qbittorrent" "sabnzbd"]);
}
