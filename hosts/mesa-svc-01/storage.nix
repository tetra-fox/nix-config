# /mnt/store                 the shared library, NFS-mounted from store-01
# /var/lib/mesa/<service>    local state for every native + container service
{
  config,
  lib,
  modules,
  siteData,
  nixosConfigurations,
  ...
}: let
  # the storage host's internal-VLAN IP (the NFS server).
  storeIp =
    (import modules.meta.lib.site-topology {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }).storageHostIp;
in {
  # gid must match store-01 (1002) or NFS group-write fails; arr-stack declares the group
  # without a gid, this pins it.
  users.groups.media = {
    gid = 1002;
  };

  systemd.tmpfiles.rules = [
    "d ${siteData} 0755 root media -"
  ];

  # the share is its own fsid=0 v4 root scoped to svc-01, so mount `:/`. automount +
  # idle-timeout + nofail so a store-01 reboot doesn't wedge boot here.
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

  # gate the media services on the mount so they don't race it and operate on the empty
  # mountpoint underneath; RequiresMountsFor pulls the automount up first.
  systemd.services = builtins.listToAttrs (map (name: {
    inherit name;
    value.unitConfig.RequiresMountsFor = ["/mnt/store"];
  }) ["sonarr" "radarr" "jellyfin" "qbittorrent" "sabnzbd"]);
}
