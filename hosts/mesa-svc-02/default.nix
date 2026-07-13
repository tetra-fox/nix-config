{modules, ...}: {
  imports = [
    ./storage.nix

    modules.profiles.server.system # base + proxmox-vm + disko (by-id) + monitoring agent
    modules.platform.sops.system # immich oauth client secret

    modules.services.immich.system
  ];

  networking.hostName = "mesa-svc-02";

  lab = {
    sops.secretsFile = ../../secrets/mesa-svc-02.yaml;

    site.hostIp = "192.168.10.131";
    site.internalIp = "10.10.0.131";
  };

  system.stateVersion = "26.11";
}
