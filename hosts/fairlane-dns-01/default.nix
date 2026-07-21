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

    # hostV6 is this box's static ULA on ens18 (the v6 heartbeat source); the shared v6 VIP lives
    # in modules/sites/fairlane-dns.nix.
    bind.ha.hostV6 = "fd00:10::160";
  };
}
