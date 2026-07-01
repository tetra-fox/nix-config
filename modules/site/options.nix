# lab.site.* option declarations. fleet-wide (not in a site's facts file) because
# site-topology + the colmena deploy output read lab.site.* on every host, not just one site's.
{lib, ...}: {
  options.lab.site = {
    hostIp = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "this host's IPv4 on its site's server VLAN (the rest of the layout is fixed per-site)";
      example = "192.168.10.130";
    };

    internalIp = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "this host's IPv4 on the isolated internal VLAN (ens19); null = not on it";
      example = "10.10.0.130";
    };
  };
}
