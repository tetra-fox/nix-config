# same address layout as mesa, see mesa.nix. two proxmox nodes, so each host sets
# lab.site.proxmoxParent
_: {
  imports = [./_common.nix];

  config.lab = {
    site = {
      domain = "fairlane.tetra.cool";
      internalCidr = "10.10.0.0/24";
      dataDir = "/var/lib/fairlane";
    };

    appliances = {
      # inter-VM traffic (nfs backups, the home. vhost) uses HAOS's internal-VLAN leg
      haosIp = "10.10.0.20";
      # two nodes, so proxmoxIp stays null
      proxmoxNodes = {
        plush = "192.168.10.212";
        pooltoy = "192.168.10.7";
      };
    };
  };
}
