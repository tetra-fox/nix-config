# /mnt/media   the shared library, NFS-mounted from fairlane-store-01. mounted at /mnt/media
# (not mesa's /mnt/store) because fairlane's arr DBs have root/download dirs baked in under
# /mnt/media -- changing the path would make every item show as missing. the passthrough disk
# itself moved to store-01 (this box is now a pure NFS client, like mesa-svc-01).
{
  config,
  lib,
  fleet,
  nixosConfigurations,
  ...
}: let
  siteData = config.lab.site.dataDir;
  storeIp =
    (import fleet.topology {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }).storageHostIp;
in {
  users.groups.media.gid = 1002;

  systemd.tmpfiles.rules = [
    "d ${siteData} 0755 root media -"
  ];

  fileSystems."/mnt/media" = {
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

  systemd.services = builtins.listToAttrs (map (name: {
    inherit name;
    value.unitConfig.RequiresMountsFor = ["/mnt/media"];
  }) ["sonarr" "radarr" "jellyfin" "qbittorrent" "sabnzbd"]);
}
