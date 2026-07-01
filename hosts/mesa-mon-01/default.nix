{
  config,
  username,
  modules,
  ...
}: {
  imports = [
    ./monitoring.nix

    modules.platform.proxmox-vm.system
    modules.platform.disko.proxmox-vm
    modules.meta.profiles.server.system

    modules.platform.sops.system
  ];

  lab.sops.secretsFile = ../../secrets/mesa-mon-01.yaml;

  networking.hostName = "mesa-mon-01";
  lab.site.hostIp = "192.168.10.140";
  lab.site.internalIp = "10.10.0.140";

  # no storage.nix here, so create the siteData root itself
  systemd.tmpfiles.rules = ["d /var/lib/mesa 0755 root root -"];

  system.stateVersion = "26.11";
}
