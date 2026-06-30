# lab.site.* option DECLARATIONS, fleet-wide (imported via perClass.nixos) so any host
# has the options even before a per-site facts module sets them. the site module
# (modules/sites/<tag>.nix) only SETS these values + does the VLAN wiring; it doesn't
# declare the options. site-topology + the colmena deploy output read lab.site.* as a
# fleet-wide contract, so the declaration can't live in one site's facts file.
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
