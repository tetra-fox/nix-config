# lab.site.* + lab.topology.* option declarations. fleet-wide (not in a site's facts file)
# because site-topology + the colmena deploy output read them on every host, not just one site's.
{lib, ...}: {
  # capabilities this host advertises for same-site service discovery. each service module
  # appends its own capability string when its enable flag is on (gated on a plain input, never
  # a derived value -- see the no-recursion rule in site-topology.nix). site-topology reads this
  # across hosts to answer "which host in my site provides X".
  options.lab.topology.provides = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    example = ["db-server" "db-client"];
  };

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
