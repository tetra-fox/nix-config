{modules, ...}: {
  imports = [
    ../common/dns-host.nix
    modules.sites.fairlane-dns
  ];

  lab = {
    site = {
      hostIp = "192.168.10.160";
      internalIp = "10.10.0.160";
      proxmoxParent = "plush";
    };

    # v6 heartbeat source
    bind.ha.hostV6 = "fd00:10::160";
  };
}
