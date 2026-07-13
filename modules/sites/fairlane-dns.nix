# fairlane-specific resolver facts (the split-horizon zone + RPZ blocklists); the generic
# resolver behaviour is in modules.services.bind.system. mirrors modules/sites/mesa-dns.nix --
# this is the proof the bind module is genuinely site-agnostic: a second site is one file.
{
  config,
  lib,
  pkgs,
  modules,
  fleet,
  nixosConfigurations,
  ...
}: let
  inherit
    ((import fleet.topology {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }))
    edgeEndpointIp
    hostRecords
    ;
in {
  imports = [modules.services.bind.system ./_dns-common.nix];

  lab.bind = {
    # fairlane has a real dual-stack WAN (Comcast), so bind must not force -4 (which would refuse
    # every v6 socket, including the v6 VIP). mesa is v4-only and leaves this default false.
    dualStack = true;

    # v6 clients must be in the internal view or they get REFUSED (the default trustedRanges is
    # v4-only). add the LAN ULA range + link-local so the ULA VIP and v6 LAN clients resolve.
    # the default v4 ranges are replaced here, so restate them alongside the v6 ones.
    trustedRanges = [
      "192.168.0.0/16"
      "10.0.0.0/8"
      "fd00::/8" # LAN ULAs (the resolver VIP + v6 clients)
      "fe80::/10" # v6 link-local
    ];

    zone = {
      name = "fairlane.tetra.cool";
      file = pkgs.replaceVars ./files/fairlane.tetra.cool.zone.in {
        nsIp = config.lab.site.hostIp;
        edgeVip = edgeEndpointIp;
        inherit hostRecords;
      };
    };
  };
}
