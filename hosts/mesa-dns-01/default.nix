{
  lib,
  modules,
  ...
}: {
  imports = [

    modules.profiles.server.system

    modules.sites.mesa-dns
  ];

  networking.hostName = "mesa-dns-01";

  # resolve to self, not the router -- routing through the router is a forwarding loop.
  # mkForce overrides the mesa site facts, which point every resolver at the router.
  networking.nameservers = lib.mkForce ["127.0.0.1"];

  lab = {
    site.hostIp = "192.168.10.160";
    # keepalived VRRP heartbeat rides ens19, so an internalIp is needed here.
    site.internalIp = "10.10.0.160";

    bind.enable = true;

    bind.ha = {
      enable = true;
      vip = "192.168.10.53";
    };
  };

  # no storage.nix here, so create the siteData root itself
  systemd.tmpfiles.rules = ["d /var/lib/mesa 0755 root root -"];

  system.stateVersion = "26.11";
}
