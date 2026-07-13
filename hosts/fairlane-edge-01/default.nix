{modules, ...}: {
  imports = [
    modules.profiles.server.system

    modules.services.caddy.system
    modules.platform.sops.system
  ];

  lab = {
    sops.secretsFile = ../../secrets/fairlane-edge-01.yaml;

    site = {
      hostIp = "192.168.10.150";
      internalIp = "10.10.0.150";
      proxmoxParent = "plush";
    };

    caddy = {
      staticTail = import ./caddy-tail.nix;

      # HA is real on fairlane's 2 nodes for stateless caddy: edge-01 on plush, edge-02 on
      # pooltoy, VIP flips. heartbeat and VIP both ride the server VLAN (see the caddy module).
      ha = {
        enable = true;
        vip = "192.168.10.155";
      };
    };
  };

  system.stateVersion = "26.11";
}
