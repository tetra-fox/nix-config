# mesa site facts, applied to every mesa-* host via the easy-hosts `mesa` tag.
#
# NOTE mesa and fairlane reuse the same 192.168.10.0/24 layout on physically-separate sites,
# so these facts MUST be per-site: mesa resolves via its own AdGuard at .53, fairlane via its
# gateway at .1.
{
  config,
  lib,
  ...
}: {
  config = {
    lab.site.domain = "mesa.tetra.cool";

    networking = {
      useDHCP = false;
      defaultGateway = "192.168.10.1";
      nameservers = ["192.168.10.1"];

      interfaces.ens18 = {
        mtu = 9000; # milkfish bridge + switch are 9000 end-to-end
        ipv4.addresses = [
          {
            address = config.lab.site.hostIp;
            prefixLength = 24;
          }
        ];
      };

      # ens19 = isolated internal VLAN (10.10.0.0/24, VLAN 1010) for VM east-west traffic.
      # no gateway/DNS here (those stay on ens18); the VLAN has no route off itself by design.
      interfaces.ens19 = lib.mkIf (config.lab.site.internalIp != null) {
        mtu = 9000;
        ipv4.addresses = [
          {
            address = config.lab.site.internalIp;
            prefixLength = 24;
          }
        ];
      };
    };

    # each host creates+owns this dir itself via tmpfiles (ownership differs per host), so no
    # tmpfiles rule here.
    _module.args.siteData = "/var/lib/mesa";

    topology.self = {
      parent = "milkfish";
      guestType = "vm";
      interfaces.ens18 = {
        virtual = true;
        physicalConnections = [(config.lib.topology.mkConnection "milkfish" "vmbr0.10")];
      };
      interfaces.ens19 = lib.mkIf (config.lab.site.internalIp != null) {
        virtual = true;
        physicalConnections = [(config.lib.topology.mkConnection "milkfish" "vmbr0.1010")];
      };
    };
  };
}
