# the mesa-specific resolver facts: the split-horizon zone (mesa.tetra.cool, wildcard -> the edge
# VIP) and the RPZ blocklists. these are the same on both mesa resolvers, so they live here once
# and both dns hosts import this; the generic resolver behaviour (views, recursion, DNSSEC, RPZ
# engine, the keepalived VIP) is in modules.services.bind.system, driven by the options this file sets.
{
  config,
  lib,
  pkgs,
  modules,
  nixosConfigurations,
  ...
}: let
  # the edge VIP the wildcard answers from, derived from site-topology so it doesn't hardcode
  # where caddy lives (the VIP when edge runs HA, else the single host).
  edgeEndpointIp =
    (import modules.meta.lib.site-topology {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }).edgeEndpointIp;
in {
  imports = [modules.services.bind.system];

  lab.bind = {
    zone = {
      name = "mesa.tetra.cool";
      # a real zone file with the two derived addresses substituted: @nsIp@ = this resolver's IP,
      # @edgeVip@ = the edge VIP the wildcard answers from.
      file = pkgs.replaceVars ./files/mesa.tetra.cool.zone.in {
        nsIp = config.lab.site.hostIp;
        edgeVip = edgeEndpointIp;
      };
    };

    # OISD (already RPZ) + the VRChat analytics blocklist (hosts format, converted). the VRChat
    # repo owner renamed Luois45 -> louisa-uno; raw.githubusercontent doesn't redirect, so the URL
    # must use louisa-uno or it 404s. small + frozen (last update jan 2024).
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
