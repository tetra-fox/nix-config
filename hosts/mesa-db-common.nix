# shared by mesa-db-01/02/03. all three nodes declare the same lab.postgres.ha config
# and roles on purpose: any node can be the leader, so each must be able to bootstrap
# and own the databases. host files keep only their IPs and sops yaml.
{
  config,
  lib,
  modules,
  fleet,
  nixosConfigurations,
  ...
}: let
  arrDbs =
    (import fleet.topology {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }).arrDatabases;
in {
  imports = [
    modules.profiles.server.system

    modules.services.postgres-ha.system
    modules.platform.sops.system
  ];

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
