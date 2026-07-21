{modules, ...}: {
  imports = [
    ../common/dns-host.nix
    modules.sites.fairlane-dns
  ];

  lab = {
    site = {
      hostIp = "192.168.10.161";
      internalIp = "10.10.0.161";
      proxmoxParent = "pooltoy";
    };

    bind.ha.hostV6 = "fd00:10::161";
  };
}
