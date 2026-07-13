# see mesa-dns-01 for the full rationale; this file differs only in hostname + IPs.
{
  config,
  lib,
  modules,
  ...
}: {
  imports = [
    modules.profiles.server.system

    modules.sites.mesa-dns
  ];

  # ask itself, never the router -- see mesa-dns-01 for why (forwarding loop).
  networking.nameservers = lib.mkForce ["127.0.0.1"];

  lab = {
    site.hostIp = "192.168.10.161";
    # VRRP heartbeat rides ens19, .53 VIP stays on ens18. see mesa-dns-01.
    site.internalIp = "10.10.0.161";

    bind.enable = true;

    bind.ha = {
      enable = true;
      vip = "192.168.10.53";
    };
  };

  systemd.tmpfiles.rules = ["d ${config.lab.site.dataDir} 0755 root root -"];

  system.stateVersion = "26.11";
}
