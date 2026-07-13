# see fairlane-dns-01; stateless bind clone pinned to the other node (pooltoy).
{
  config,
  lib,
  modules,
  ...
}: {
  imports = [
    modules.profiles.server.system

    modules.sites.fairlane-dns
  ];

  networking.hostName = "fairlane-dns-02";

  networking.nameservers = lib.mkForce ["127.0.0.1"];

  lab = {
    site = {
      hostIp = "192.168.10.161";
      internalIp = "10.10.0.161";
      proxmoxParent = "pooltoy";
    };

    bind = {
      enable = true;

      ha = {
        enable = true;
        vip = "192.168.10.53";
        vip6 = "fd00:10::53";
        hostV6 = "fd00:10::161";
      };
    };
  };

  systemd.tmpfiles.rules = ["d ${config.lab.site.dataDir} 0755 root root -"];

  system.stateVersion = "26.11";
}
