{
  imports = [../common/mesa-db.nix];

  lab = {
    site.hostIp = "192.168.10.111";
    site.internalIp = "10.10.0.111";
  };
}
