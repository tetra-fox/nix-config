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

    modules.services.authentik.system
    modules.platform.sops.system
  ];

  lab.sops.secretsFile = ../../secrets/mesa-auth-01.yaml;

  networking.hostName = "mesa-auth-01";
  lab.site.hostIp = "192.168.10.120";
  lab.site.internalIp = "10.10.0.120";

  lab.authentik.enable = true;

  system.stateVersion = "26.11";
}
