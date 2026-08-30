# mesa site facts, applied to every mesa-* host via the easy-hosts `mesa` tag.
#
# NOTE mesa and fairlane reuse the same 192.168.10.0/24 + 10.10.0.0/24 layout on
# physically-separate sites, so these facts MUST be per-site. same layout on purpose (one
# mental model), which also means the sites can never route to each other; if that changes,
# renumber a site. the shared proxmox-VM network shape lives in _common.nix; mesa is a
# single-node site, so the proxmox parent is a site-wide constant here, not a per-host fact.
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
      proxmoxNodes.milkfish = "192.168.10.2";
    };
  };
}
