{
  config,
  lib,
  caps,
  ...
}: {
  imports = [./apikey.nix];

  lab.topology.provides = [caps.media.name];
  lab.topology.routes = [
    {
      host = "jellyfin.${config.lab.site.domain}";
      port = 8096;
    }
  ];

  # pin the uid; the NFS share squashes on uid, not name, and upstream auto-allocates it
  users.users.jellyfin.uid = 991;

  services.jellyfin = {
    enable = true;
    group = lib.mkDefault "media";
    openFirewall = true;
    dataDir = "${config.lab.site.dataDir}/jellyfin/data";
    cacheDir = "${config.lab.site.dataDir}/jellyfin/cache";
    configDir = "${config.lab.site.dataDir}/jellyfin/config";
    logDir = "${config.lab.site.dataDir}/jellyfin/log";
  };
}
