# see mesa-dns-01 for the full rationale; this file differs only in hostname + IPs.
{
  lib,
  username,
  modules,
  ...
}: {
  imports = [
    ./monitoring.nix

    modules.platform.proxmox-vm.system
    modules.platform.disko.proxmox-vm
    modules.meta.profiles.server.system

    modules.sites.mesa-dns
  ];

  networking.hostName = "mesa-dns-02";
  lab.site.hostIp = "192.168.10.161";
  # VRRP heartbeat rides ens19, .53 VIP stays on ens18. see mesa-dns-01.
  lab.site.internalIp = "10.10.0.161";

  # ask itself, never the router -- see mesa-dns-01 for why (forwarding loop).
  networking.nameservers = lib.mkForce ["127.0.0.1"];

  lab.bind.enable = true;

  lab.bind.ha = {
    enable = true;
    vip = "192.168.10.53";
  };

  systemd.tmpfiles.rules = ["d /var/lib/mesa 0755 root root -"];

  system.stateVersion = "26.11";
}
