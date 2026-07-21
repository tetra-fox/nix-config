# host-role boilerplate shared by every site's edge (mesa-edge-01/02, fairlane-edge-01/02): a
# stateless caddy node in a keepalived HA pair, each with its own ACME certs, behind a shared VIP.
# heartbeat and VIP both ride the server VLAN (see the caddy module); -01 and -02 pin to different
# proxmox hosts so a node death leaves one edge alive. the host file sets only its sops file + IPs.
{
  config,
  lib,
  modules,
  fleet,
  ...
}: let
  sitePrefix = import fleet.site-prefix {inherit lib;};
  site = sitePrefix config.networking.hostName;
in {
  imports = [
    modules.profiles.server.system

    modules.services.caddy.system
  ];

  # the site's Caddyfile tail, templated over the host's lab facts. no pathExists guard,
  # same rule as the flake's perTag: an edge site without a tail file should fail loudly
  lab.caddy.staticTail = import (./. + "/${site}-caddy-tail.nix") {inherit (config) lab;};

  lab.caddy.ha = {
    enable = true;
    vip = "192.168.10.155";
  };

  system.stateVersion = "26.11";
}
