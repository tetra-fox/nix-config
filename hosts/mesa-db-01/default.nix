{
  imports = [../common/mesa-db.nix];

  lab = {
    sops.secretsFile = ../../secrets/mesa-db-01.yaml;

    site.hostIp = "192.168.10.110";
    site.internalIp = "10.10.0.110";
  };
}
