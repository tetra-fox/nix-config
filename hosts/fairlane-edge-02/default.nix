_: {
  imports = [../common/edge-host.nix];

  lab = {
    site = {
      hostIp = "192.168.10.151";
      internalIp = "10.10.0.151";
      proxmoxParent = "pooltoy";
    };
  };
}
