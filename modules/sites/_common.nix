# the proxmox-VM network shape every site shares: static v4 on the server-VLAN NIC, an
# optional isolated internal-VLAN NIC, and the topology parent edge. imported by each
# site facts file; the per-site deltas (domain, dataDir, internalCidr, proxmox parent)
# stay in the site file, per-host facts (hostIp, internalIp, multi-node proxmoxParent)
# in the host file.
{
  config,
  lib,
  ...
}: {
  networking = {
    useDHCP = false;
    # both sites reuse the same 192.168.10.0/24 server-VLAN plan; a site with a
    # different layout overrides these in its facts file
    defaultGateway = lib.mkDefault "192.168.10.1";
    nameservers = lib.mkDefault ["192.168.10.1"];

    interfaces.${config.lab.site.serverInterface} = {
      mtu = 9000; # proxmox bridges + the switch run 9000 end-to-end at both sites
      ipv4.addresses = [
        {
          address = config.lab.site.hostIp;
          prefixLength = 24;
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
          prefixLength = 24;
        }
      ];
    };
  };

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
