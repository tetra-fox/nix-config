# mesa and fairlane share one address layout on purpose, so the sites can never route to each
# other. if that changes, renumber a site
{lib, ...}: {
  imports = [./_common.nix];

  config.lab = {
    site = {
      domain = "mesa.tetra.cool";
      internalCidr = "10.10.0.0/24";
      dataDir = "/var/lib/mesa";
      # hosts on bickle set it themselves. two of the three db nodes stay on milkfish, so losing
      # bickle keeps etcd quorum while the apps are still up
      proxmoxParent = lib.mkDefault "milkfish";
    };

    appliances = {
      # inter-VM traffic uses HAOS's internal-VLAN leg only, the server VLAN is for inter-VLAN routing
      haosIp = "10.10.0.20";
      proxmoxNodes = {
        milkfish = "192.168.10.2";
        bickle = "192.168.10.3";
      };
    };
  };
}
