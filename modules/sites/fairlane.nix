# fairlane site facts, applied to every fairlane-* host via the easy-hosts `fairlane` tag.
#
# fairlane and mesa reuse the same 192.168.10.0/24 + 10.10.0.0/24 (VLAN 1010) layout on
# physically-separate sites, so these facts MUST be per-site. the difference from mesa: fairlane
# is a two-proxmox-node site (plush + pooltoy), so a host declares which node it's on via
# lab.site.proxmoxParent (mesa is single-node milkfish, hardcoded there).
{
  config,
  lib,
  ...
}: {
  config = {
    lab.site.domain = "fairlane.tetra.cool";
    lab.site.internalCidr = "10.10.0.0/24";

    networking = {
      useDHCP = false;
      defaultGateway = "192.168.10.1";
      nameservers = ["192.168.10.1"];

      interfaces.${config.lab.site.serverInterface} = {
        mtu = 9000;
        ipv4.addresses = [
          {
            address = config.lab.site.hostIp;
            prefixLength = 24;
          }
        ];
      };

      # the isolated internal VLAN (10.10.0.0/24, VLAN 1010) for VM east-west traffic, same
      # as mesa. no gateway/DNS; no route off itself. only hosts that declare an internalIp.
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

    _module.args.siteData = "/var/lib/fairlane";

    # the proxmox node this VM runs on -- plush or pooltoy (fairlane is a 2-node cluster). unlike
    # mesa's single milkfish, this varies per host, so the topology parent reads it.
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
  };
}
