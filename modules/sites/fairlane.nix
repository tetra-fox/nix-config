# fairlane site facts, applied to every fairlane-* host via the easy-hosts `fairlane` tag.
#
# fairlane and mesa reuse the same 192.168.10.0/24 + 10.10.0.0/24 layout on physically-
# separate sites, so these facts MUST be per-site. the shared proxmox-VM network shape
# lives in _common.nix; fairlane is a two-proxmox-node site (plush + pooltoy), so each
# host declares which node it runs on via lab.site.proxmoxParent.
_: {
  imports = [./_common.nix];

  config.lab.site = {
    domain = "fairlane.tetra.cool";
    internalCidr = "10.10.0.0/24";
    # each host creates+owns this dir itself via tmpfiles (ownership differs per host),
    # so no tmpfiles rule here
    dataDir = "/var/lib/fairlane";
  };
}
