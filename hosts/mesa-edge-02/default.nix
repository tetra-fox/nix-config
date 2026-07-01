# see mesa-edge-01; caddy is stateless so this is a clone with its own ACME certs.
{
  username,
  modules,
  ...
}: {
  imports = [
    ./monitoring.nix

    modules.platform.proxmox-vm.system
    modules.platform.disko.proxmox-vm
    modules.meta.profiles.server.system

    modules.services.caddy.system
    modules.platform.sops.system
  ];

  lab.sops.secretsFile = ../../secrets/mesa-edge-02.yaml;

  networking.hostName = "mesa-edge-02";
  lab.site.hostIp = "192.168.10.151";
  lab.site.internalIp = "10.10.0.151";

  lab.caddy.caddyfile = ../mesa-edge-01/files/caddy/Caddyfile;

  lab.caddy.ha = {
    enable = true;
    vip = "192.168.10.155";
  };

  system.stateVersion = "26.11";
}
