# mesa site facts, applied to every mesa-* host via the easy-hosts `mesa` tag. the
# things that are the same for ALL mesa boxes -- gateway, DNS, VLAN layout, jumbo
# frames, the siteData root -- live here once instead of being copy-pasted into each
# host's default.nix. a host only declares its own IP via lab.site.hostIp.
#
# NOTE the mesa and fairlane sites reuse the same 192.168.10.0/24 layout (the CIDRs
# collide across physically-separate sites), so these facts MUST be per-site, not
# global: mesa resolves via its own AdGuard at .53, fairlane via its gateway at .1.
# lab.site.* options are declared fleet-wide in modules/site/options.nix; this file only
# SETS the mesa-specific values + wires the two VLANs.
{
  config,
  lib,
  ...
}: {
  config = {
    networking = {
      # ens18 = server vlan (LAN-routable, default route). single-NIC proxmox guests.
      useDHCP = false;
      defaultGateway = "192.168.10.1";
      nameservers = ["192.168.10.1"];

      interfaces.ens18 = {
        mtu = 9000; # jumbo frames; milkfish bridge + switch are 9000 end-to-end
        ipv4.addresses = [
          {
            address = config.lab.site.hostIp;
            prefixLength = 24;
          }
        ];
      };

      # ens19 = isolated internal VLAN (10.10.0.0/24, VLAN 1010) for VM east-west traffic
      # (postgres, NFS). just an address on the segment -- no gateway/DNS here (those stay
      # on ens18), the VLAN has no route off itself by design. mtu pinned to 9000 so jumbo
      # frames on the east-west fabric don't silently depend on the proxmox bridge default.
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

    # all mesa state lives under one root so a single backup target catches it. just
    # the path is a site fact; each host creates+owns the dir itself via tmpfiles
    # (service hosts want it group-owned by `media`, mon-01 just root) -- so the
    # tmpfiles rule stays per-host, not here.
    _module.args.siteData = "/var/lib/mesa";

    # mesa proxmox guests parent the milkfish node in the topology
    topology.self.parent = "milkfish";
  };
}
