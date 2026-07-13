{
  imports = [../mesa-db-common.nix];

  lab = {
    sops.secretsFile = ../../secrets/mesa-db-03.yaml;

    site.hostIp = "192.168.10.112";
    site.internalIp = "10.10.0.112";
  };
}
