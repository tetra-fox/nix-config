{
  config,
  modules,
  ...
}: {
  imports = [
    ./monitoring.nix

    modules.profiles.server.system
  ];

  lab = {
    site = {
      hostIp = "192.168.10.140";
      internalIp = "10.10.0.140";
      proxmoxParent = "pooltoy";
    };
  };

  system.stateVersion = "26.11";
}
