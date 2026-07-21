{
  imports = [
    ../common/mon-host.nix
    ./monitoring.nix
  ];

  lab = {
    site.hostIp = "192.168.10.140";
    site.internalIp = "10.10.0.140";
  };
}
