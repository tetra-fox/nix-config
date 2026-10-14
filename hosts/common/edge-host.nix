# each node has its own ACME certs
{
  config,
  modules,
  fleet,
  ...
}: let
  site = fleet.site-prefix config.networking.hostName;
in {
  imports = [
    modules.profiles.server.system

    modules.services.caddy.system
  ];

  # no pathExists guard, an edge site without a tail file should fail loudly
  lab.caddy.staticTail = import (./. + "/${site}-caddy-tail.nix") {inherit (config) lab;};

  lab.caddy.ha = {
    enable = true;
    vip = "192.168.10.155";
  };

  system.stateVersion = "26.11";
}
