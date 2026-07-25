# mesa site facts, applied to every mesa-* host via the easy-hosts `mesa` tag.
#
# NOTE mesa and fairlane reuse the same 192.168.10.0/24 + 10.10.0.0/24 layout on
# physically-separate sites, so these facts MUST be per-site. the identical layout is
# deliberate (one mental model, both sites consume the same modules unparameterized) and
# it forecloses ever routing or bridging between the sites: overlapping subnets can't
# route, and L2 adjacency would collide the VIPs and VRIDs. accepted on purpose,
# cross-site traffic is a non-goal; if that ever changes, renumber a site, don't tunnel.
# the shared proxmox-VM network shape lives in _common.nix; mesa is a single-node site,
# so the proxmox parent is a site-wide constant here instead of a per-host fact.
_: {
  imports = [./_common.nix];

  config.lab = {
    site = {
      domain = "mesa.tetra.cool";
      internalCidr = "10.10.0.0/24";
      # created by _common.nix's tmpfiles rule, group per lab.site.dataDirGroup
      dataDir = "/var/lib/mesa";
      proxmoxParent = "milkfish";
    };

    appliances = {
      # HAOS is multihomed; inter-VM traffic rides its internal-VLAN leg exclusively
      # (the server VLAN is for inter-VLAN routing)
      haosIp = "10.10.0.20";
      # milkfish
      proxmoxIp = "192.168.10.2";
    };
  };
}
