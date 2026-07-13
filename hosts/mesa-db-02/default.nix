# all three db nodes declare the same lab.postgres.ha config and roles; any node can be the
# leader, so each must be able to bootstrap/own the databases.
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

  lab = {
    sops.secretsFile = ../../secrets/mesa-db-02.yaml;

    site.hostIp = "192.168.10.111";
    site.internalIp = "10.10.0.111";

    postgres = {
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
  };

  system.stateVersion = "26.11";
}
