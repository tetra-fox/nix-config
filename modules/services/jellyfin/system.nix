{
  config,
  lib,
  caps,
  ...
}: {
  imports = [./apikey.nix];

  # upstream services.jellyfin has no port option (8096 is baked into its kestrel config);
  # published here so the route and co-located consumers (arr-stack's jellyfin-notify)
  # read one fact instead of restating the number
  options.lab.jellyfin.port = lib.mkOption {
    type = lib.types.port;
    readOnly = true;
    default = 8096;
  };

  config = {
    lab.topology.provides = [caps.media.name];
    lab.topology.routes = [
      {
        host = "jellyfin.${config.lab.site.domain}";
        port = config.lab.jellyfin.port;
      }
    ];

    # pin the uid; the NFS share squashes on uid, not name, and upstream auto-allocates it
    users.users.jellyfin.uid = 991;

    # declare the group here too, not just in arr-stack: jellyfin must not depend on being
    # co-deployed with the arrs for its group to exist (equal gid defs merge fine)
    users.groups.${config.lab.media.group}.gid = config.lab.media.gid;

    services.jellyfin = {
      enable = true;
      group = lib.mkDefault config.lab.media.group;
      openFirewall = true;
      dataDir = "${config.lab.site.dataDir}/jellyfin/data";
      cacheDir = "${config.lab.site.dataDir}/jellyfin/cache";
      configDir = "${config.lab.site.dataDir}/jellyfin/config";
      logDir = "${config.lab.site.dataDir}/jellyfin/log";
    };
  };
}
