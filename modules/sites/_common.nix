# the proxmox-VM network shape every site shares: static v4 on the server-VLAN NIC, an
# optional isolated internal-VLAN NIC, and the topology parent edge. imported by each
# site facts file; the per-site deltas (domain, dataDir, internalCidr, proxmox parent)
# stay in the site file, per-host facts (hostIp, internalIp, multi-node proxmoxParent)
# in the host file.
{
  config,
  lib,
  ...
}: let
  # both site VLANs are /24; stated once so the two address blocks can't drift apart
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

    # the isolated internal VLAN (VLAN 1010) for VM east-west traffic. no gateway/DNS
    # here (those stay on the server VLAN); no route off itself by design. only on
    # hosts that declare an internalIp.
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

  # the site data root, owned once here instead of per host; only the group varies
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
