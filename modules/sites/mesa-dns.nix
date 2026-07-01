# mesa-specific resolver facts (the split-horizon zone + RPZ blocklists); the generic resolver
# behaviour is in modules.services.bind.system, driven by the options this file sets.
{
  config,
  lib,
  pkgs,
  modules,
  nixosConfigurations,
  ...
}: let
  inherit
    ((import modules.meta.lib.site-topology {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }))
    edgeEndpointIp
    ;
in {
  imports = [modules.services.bind.system];

  lab.bind = {
    zone = {
      name = "mesa.tetra.cool";
      file = pkgs.replaceVars ./files/mesa.tetra.cool.zone.in {
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
