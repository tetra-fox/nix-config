_: {
  imports = [../common/edge-host.nix];

  lab = {
    site.hostIp = "192.168.10.150";
    site.internalIp = "10.10.0.150";
  };
}
