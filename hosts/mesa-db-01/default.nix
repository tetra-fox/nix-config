# single postgres server while mesa has one proxmox node. imports ../common/mesa-db-ha.nix
# instead once db-02/03 come back
{modules, ...}: {
  imports = [
    ../common/mesa-db.nix
    modules.services.postgres.system
  ];

  lab = {
    site.hostIp = "192.168.10.110";
    site.internalIp = "10.10.0.110";

    postgres = {
      server.enable = true;
      openFirewall = true;
    };
  };
}
