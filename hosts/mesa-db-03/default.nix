{
  imports = [../common/mesa-db-ha.nix];

  lab = {
    site.hostIp = "192.168.10.112";
    site.internalIp = "10.10.0.112";
  };
}
