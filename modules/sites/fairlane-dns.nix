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
    ;
in {
  imports = [modules.services.bind.system];

  lab.bind = {
    zone = {
      name = "fairlane.tetra.cool";
      file = pkgs.replaceVars ./files/fairlane.tetra.cool.zone.in {
        nsIp = config.lab.site.hostIp;
        edgeVip = edgeEndpointIp;
      };
    };

    rpzLists = [
      {
        name = "oisd.rpz";
        url = "https://big.oisd.nl/rpz";
        format = "rpz";
      }
      {
        name = "vrchat.rpz";
        url = "https://raw.githubusercontent.com/louisa-uno/VRChatAnalyticsBlocklist/main/hosts.txt";
        format = "hosts";
      }
    ];
  };
}
