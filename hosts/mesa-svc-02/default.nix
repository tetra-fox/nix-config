{modules, ...}: {
  imports = [
    ./storage.nix

    modules.profiles.server.system

    modules.services.immich.system
  ];

  lab = {
    site.hostIp = "192.168.10.131";
    site.internalIp = "10.10.0.131";

    # not a secret
    immich.oauth.clientId = "6Yn7cayRUwkkNHXKOWFHpMIjE7dr3RpAIsYLMsK4";
  };

  system.stateVersion = "26.11";
}
