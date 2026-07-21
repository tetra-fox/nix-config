{modules, ...}: {
  imports = [
    ./storage.nix

    modules.profiles.server.system # base + proxmox-vm + disko (by-id) + monitoring agent

    modules.services.immich.system
  ];

  lab = {
    site.hostIp = "192.168.10.131";
    site.internalIp = "10.10.0.131";

    # the client id authentik assigned to the immich application (not a secret; the
    # client secret rides in via sops)
    immich.oauth.clientId = "6Yn7cayRUwkkNHXKOWFHpMIjE7dr3RpAIsYLMsK4";
  };

  system.stateVersion = "26.11";
}
