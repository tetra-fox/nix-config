# all three db nodes declare the same lab.postgres.ha config and roles; any node can be the
# leader, so each must be able to bootstrap/own the databases.
{
  config,
  lib,
  username,
  modules,
  nixosConfigurations,
  ...
}: let
  arrDbs =
    (import modules.meta.lib.site-topology {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }).arrDatabases;
in {
  imports = [
    ./monitoring.nix

    modules.platform.proxmox-vm.system
    modules.platform.disko.proxmox-vm
    modules.meta.profiles.server.system

    modules.services.postgres-ha.system
    modules.platform.sops.system
  ];

  lab.sops.secretsFile = ../../secrets/mesa-db-02.yaml;

  networking.hostName = "mesa-db-02";
  lab.site.hostIp = "192.168.10.111";
  lab.site.internalIp = "10.10.0.111";

  lab.postgres = {
    ha = {
      enable = true;
      vip = "10.10.0.115";
    };
    admin.enable = true;

    # admin-VLAN direct psql; fleet clients are derived from their client.enable flag.
    extraAllowedCidrs = ["192.168.20.0/24"];

    roles = {
      arr = {
        passwordSecret = "arr/pg_pass";
        owns = arrDbs;
      };
      authentik = {
        passwordSecret = "auth/pg_pass";
        owns = ["authentik"];
      };
    };
  };

  system.stateVersion = "26.11";
}
