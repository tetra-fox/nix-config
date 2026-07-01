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

  networking.hostName = "mesa-edge-01";

  lab = {
    sops.secretsFile = ../../secrets/mesa-edge-01.yaml;

    site.hostIp = "192.168.10.150";
    site.internalIp = "10.10.0.150";

    caddy.caddyfile = ./files/caddy/Caddyfile;

    caddy.ha = {
      enable = true;
      vip = "192.168.10.155";
    };
  };

  system.stateVersion = "26.11";
}
