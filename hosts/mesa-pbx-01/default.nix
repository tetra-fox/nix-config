{modules, ...}: {
  imports = [
    modules.profiles.server.system
    ./pbx.nix
  ];

  lab.site = {
    hostIp = "192.168.10.170";
    internalIp = "10.10.0.170";
  };

  system.stateVersion = "26.11";
}
