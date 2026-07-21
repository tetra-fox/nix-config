{
  imports = [../common/mesa-db.nix];

  lab = {
    sops.secretsFile = ../../secrets/mesa-db-02.yaml;

    site.hostIp = "192.168.10.111";
    site.internalIp = "10.10.0.111";
  };
}
