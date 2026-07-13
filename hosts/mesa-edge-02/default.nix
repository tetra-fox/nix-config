# see mesa-edge-01; caddy is stateless so this is a clone with its own ACME certs.
{modules, ...}: {
  imports = [
    modules.profiles.server.system

    modules.services.caddy.system
    modules.platform.sops.system
  ];

  networking.hostName = "mesa-edge-02";

  lab = {
    sops.secretsFile = ../../secrets/mesa-edge-02.yaml;

    site.hostIp = "192.168.10.151";
    site.internalIp = "10.10.0.151";

    caddy.staticTail = import ../mesa-edge-01/caddy-tail.nix;

    caddy.ha = {
      enable = true;
      vip = "192.168.10.155";
    };
  };

  system.stateVersion = "26.11";
}
