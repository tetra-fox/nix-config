{
  config,
  lib,
  caps,
  ...
}: {
  imports = [./apikey.nix ./ldap.nix];

  # upstream has no port option, 8096 is baked into its kestrel config
  options.lab.jellyfin.port = lib.mkOption {
    type = lib.types.port;
    readOnly = true;
    default = 8096;
  };

  # read by authentik for the app's launch url, the ldap provider has none of its own
  options.lab.jellyfin.host = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = "jellyfin.${config.lab.site.domain}";
  };

  config = {
    lab.topology.provides = [caps.media.name];
    lab.topology.routes = [
      {
        inherit (config.lab.jellyfin) host port;
      }
    ];

    # pin the uid: NFS squashes on uid, not name
    users.users.jellyfin.uid = 991;

    # also declared by arr-stack, jellyfin shouldn't depend on being co-deployed
    users.groups.${config.lab.media.group}.gid = config.lab.media.gid;

    services.jellyfin = {
      enable = true;
      group = lib.mkDefault config.lab.media.group;
      # clients come through caddy, the route opens 8096 to the edge hosts
      openFirewall = false;
      dataDir = "${config.lab.site.dataDir}/jellyfin/data";
      cacheDir = "${config.lab.site.dataDir}/jellyfin/cache";
      configDir = "${config.lab.site.dataDir}/jellyfin/config";
      logDir = "${config.lab.site.dataDir}/jellyfin/log";
    };
  };
}
