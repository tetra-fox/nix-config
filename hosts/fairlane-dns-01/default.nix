{
  lib,
  modules,
  ...
}: {
  imports = [
    modules.profiles.server.system

    modules.sites.fairlane-dns
  ];

  networking.hostName = "fairlane-dns-01";

  # resolve to self, not the router (routing through the router is a forwarding loop).
  networking.nameservers = lib.mkForce ["127.0.0.1"];

  lab = {
    site.hostIp = "192.168.10.160";
    site.internalIp = "10.10.0.160"; # keepalived VRRP heartbeat rides ens19
    site.proxmoxParent = "plush";

    bind.enable = true;

    # dns is stateless, so HA is real on 2 nodes: dns-01 on plush, dns-02 on pooltoy, VIP flips.
    bind.ha = {
      enable = true;
      vip = "192.168.10.53";
    };
  };

  # no storage.nix here, so create the siteData root itself
  systemd.tmpfiles.rules = ["d /var/lib/fairlane 0755 root root -"];

  system.stateVersion = "26.11";
}
