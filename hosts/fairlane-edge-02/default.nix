# see fairlane-edge-01; caddy is stateless so this is a clone with its own ACME certs, pinned
# to the other proxmox node (pooltoy) so a node death leaves one edge alive.
{modules, ...}: {
  imports = [
    ./monitoring.nix

    modules.profiles.server.system

    modules.services.caddy.system
    modules.platform.sops.system
  ];

  networking.hostName = "fairlane-edge-02";

  lab = {
    sops.secretsFile = ../../secrets/fairlane-edge-02.yaml;

    site.hostIp = "192.168.10.151";
    site.internalIp = "10.10.0.151";
    site.proxmoxParent = "pooltoy";

    caddy.caddyfile = ../fairlane-edge-01/files/caddy/Caddyfile;

    caddy.ha = {
      enable = true;
      vip = "192.168.10.155";
    };
  };

  system.stateVersion = "26.11";
}
