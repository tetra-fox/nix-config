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

  lab.sops.secretsFile = ../../secrets/mesa-edge-01.yaml;

  networking.hostName = "mesa-edge-01";
  lab.site.hostIp = "192.168.10.150";
  lab.site.internalIp = "10.10.0.150";

  lab.caddy.caddyfile = ./files/caddy/Caddyfile;

  lab.caddy.ha = {
    enable = true;
    vip = "192.168.10.155";
  };

  system.stateVersion = "26.11";
}
