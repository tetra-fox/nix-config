# svc-01 is now an NFS CLIENT of mesa-store-01: the media disk + samba shares moved to
# the storage tier (Phase 1). this box mounts the shared library over NFS and keeps
# running the arrs + qbit/sab, which write into it as their pinned uids (Phase 0a) so
# files land <svc-uid>:media, not nobody.
#
# /mnt/store                 the shared library, NFS-mounted from store-01
# /var/lib/mesa/<service>    local state for every native + container service
# siteData (/var/lib/mesa) comes from the `mesa` site tag (modules/sites/mesa.nix)
{
  config,
  lib,
  modules,
  siteData,
  nixosConfigurations,
  ...
}: let
  # the storage host's internal-VLAN IP, derived (NFS server) -- no hardcoded store-01 IP.
  storeIp =
    (import modules.meta.lib.site-topology {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }).storageHostIp;
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

  # mount the library over NFSv4 from store-01 at /mnt/store. the store share is its own
  # fsid=0 v4 root scoped to svc-01, so the client mounts `:/` (svc-01 can't even see
  # store-01's other shares -- separate per-client namespaces). automount + idle-timeout
  # so the mount comes up on first access and a store-01 reboot doesn't wedge svc-01;
  # nofail keeps boot non-blocking. jumbo MTU 9000 is set site-wide (modules/sites/mesa.nix).
  fileSystems."/mnt/store" = {
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
    value.unitConfig.RequiresMountsFor = ["/mnt/store"];
  }) ["sonarr" "radarr" "jellyfin" "qbittorrent" "sabnzbd"]);
}
