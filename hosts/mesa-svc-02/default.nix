{modules, ...}: {
  imports = [
    ./storage.nix

    modules.profiles.server.system # base + proxmox-vm + disko (by-id) + monitoring agent

    modules.services.immich.system
  ];

  networking.hostName = "mesa-svc-02";

  lab = {
    # no sops: immich's postgres runs locally and connects over the unix socket with
    # peer auth, so there's no db password (or any other secret) to decrypt here.
    site.hostIp = "192.168.10.131";
    site.internalIp = "10.10.0.131";
  };

  system.stateVersion = "26.11";
}
