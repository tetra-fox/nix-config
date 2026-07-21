# host-role boilerplate shared by every site's edge (mesa-edge-01/02, fairlane-edge-01/02): a
# stateless caddy node in a keepalived HA pair, each with its own ACME certs, behind a shared VIP.
# heartbeat and VIP both ride the server VLAN (see the caddy module); -01 and -02 pin to different
# proxmox hosts so a node death leaves one edge alive. the host file sets its sops file, IPs, and
# the site's Caddyfile tail (hosts/common/<site>-caddy-tail.nix).
{modules, ...}: {
  imports = [
    modules.profiles.server.system

    modules.services.caddy.system
    modules.platform.sops.system
  ];

  lab.caddy.ha = {
    enable = true;
    vip = "192.168.10.155";
  };

  system.stateVersion = "26.11";
}
