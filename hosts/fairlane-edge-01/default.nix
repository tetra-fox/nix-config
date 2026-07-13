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
      caddyfile = ./files/caddy/Caddyfile;

      # HA is real on fairlane's 2 nodes for stateless caddy: edge-01 on plush, edge-02 on
      # pooltoy, VIP flips. VRRP heartbeat rides ens19, the VIP lands on ens18 (server VLAN).
      ha = {
        enable = true;
        vip = "192.168.10.155";
      };
    };
  };

  system.stateVersion = "26.11";
}
