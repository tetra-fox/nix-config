{
  imports = [../common/mesa-db-ha.nix];

  lab = {
    site = {
      hostIp = "192.168.10.112";
      internalIp = "10.10.0.112";
      proxmoxParent = "bickle";
    };
  };
}
