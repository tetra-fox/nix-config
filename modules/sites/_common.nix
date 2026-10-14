# per-site deltas live in the site facts file, per-host facts in the host file
{
  config,
  lib,
  ...
}: let
  prefixLength = 24;
  iface = config.lab.site.serverInterface;
in {
  networking = {
    useDHCP = false;
    defaultGateway = lib.mkDefault config.lab.net.gateway;
    nameservers = lib.mkDefault [config.lab.net.gateway];

    interfaces.${iface} = {
      mtu = 9000; # proxmox bridges + the switch run 9000 end-to-end at both sites
      ipv4.addresses = [
        {
          address = config.lab.site.hostIp;
          inherit prefixLength;
        }
      ];
    };

    # VLAN 1010, east-west only: no gateway or DNS, no route off itself by design
    interfaces.${config.lab.site.internalInterface} = lib.mkIf (config.lab.site.internalIp != null) {
      mtu = 9000;
      ipv4.addresses = [
        {
          address = config.lab.site.internalIp;
          inherit prefixLength;
        }
      ];
    };
  };

  # nixpkgs only puts the default-gateway iface into network-online. without this the internal
  # address races nfs mounts and cluster daemons at boot and is removed before them at shutdown
  systemd.services."network-addresses-${config.lab.site.internalInterface}".wantedBy =
    lib.mkIf (config.lab.site.internalIp != null) ["network-online.target"];

  systemd.tmpfiles.rules = lib.mkIf (config.lab.site.dataDir != null) [
    "d ${config.lab.site.dataDir} 0755 root ${config.lab.site.dataDirGroup} -"
  ];

  topology.self = {
    parent = config.lab.site.proxmoxParent;
    guestType = "vm";
    interfaces.${config.lab.site.serverInterface} = {
      virtual = true;
      physicalConnections = [(config.lib.topology.mkConnection config.lab.site.proxmoxParent "vmbr0.10")];
    };
    interfaces.${config.lab.site.internalInterface} = lib.mkIf (config.lab.site.internalIp != null) {
      virtual = true;
      physicalConnections = [(config.lib.topology.mkConnection config.lab.site.proxmoxParent "vmbr0.1010")];
    };
  };
}
