{modules, ...}: {
  imports = [
    modules.profiles.server.system

    modules.services.store-mount.system
    modules.services.podman.system

    ./asf.nix
    ./bambuddy.nix
    ./nowplaying.nix
    ./radio.nix
  ];

  lab.site = {
    hostIp = "192.168.10.132";
    internalIp = "10.10.0.132";
    proxmoxParent = "bickle";
  };

  system.stateVersion = "26.11";
}
