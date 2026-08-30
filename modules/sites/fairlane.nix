# fairlane site facts, applied to every fairlane-* host via the easy-hosts `fairlane` tag.
#
# fairlane and mesa reuse the same 192.168.10.0/24 + 10.10.0.0/24 layout on physically-
# separate sites, so these facts MUST be per-site (and the sites can never route to each
# other, see mesa.nix). the shared proxmox-VM network shape lives in _common.nix; fairlane
# is a two-proxmox-node site (plush + pooltoy), so each host declares which node it runs
# on via lab.site.proxmoxParent.
_: {
  imports = [./_common.nix];

  config.lab = {
    site = {
      domain = "fairlane.tetra.cool";
      internalCidr = "10.10.0.0/24";
      # created by _common.nix's tmpfiles rule, group per lab.site.dataDirGroup
      dataDir = "/var/lib/fairlane";
    };

    appliances = {
      # HAOS is multihomed, same as mesa's: inter-VM traffic (the nfs backup target, the
      # edge's home. vhost) rides its internal-VLAN leg, and the site reuses mesa's host
      # octet for it because both sites are built to the same address plan
      haosIp = "10.10.0.20";
      # two nodes, so the derived proxmoxIp stays null: there's no single web UI for the
      # edge to proxy or the topology to draw. monitoring scrapes both by name
      proxmoxNodes = {
        plush = "192.168.10.212";
        pooltoy = "192.168.10.7";
      };
    };
  };
}
