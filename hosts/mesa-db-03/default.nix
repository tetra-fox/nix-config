# see mesa-db-02 for the shared HA design; this file differs only in hostname + IPs.
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
    sops.secretsFile = ../../secrets/mesa-db-03.yaml;

    site.hostIp = "192.168.10.112";
    site.internalIp = "10.10.0.112";

    postgres = {
      ha = {
        enable = true;
        vip = "10.10.0.115";
      };
      admin.enable = true;

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
