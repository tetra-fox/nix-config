# mesa site facts, applied to every mesa-* host via the easy-hosts `mesa` tag.
#
# NOTE mesa and fairlane reuse the same 192.168.10.0/24 + 10.10.0.0/24 layout on
# physically-separate sites, so these facts MUST be per-site. the shared proxmox-VM
# network shape lives in _common.nix; mesa is a single-node site, so the proxmox
# parent is a site-wide constant here instead of a per-host fact.
_: {
  imports = [./_common.nix];

  config.lab.site = {
    domain = "mesa.tetra.cool";
    internalCidr = "10.10.0.0/24";
    # each host creates+owns this dir itself via tmpfiles (ownership differs per host),
    # so no tmpfiles rule here
    dataDir = "/var/lib/mesa";
    proxmoxParent = "milkfish";
  };
}
