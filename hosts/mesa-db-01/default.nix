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
    ./monitoring.nix

    modules.platform.proxmox-vm.system
    modules.platform.disko.proxmox-vm
    modules.meta.profiles.server.system

    modules.services.postgres-ha.system
    modules.platform.sops.system
  ];

  networking.hostName = "mesa-db-01";

  lab = {
    sops.secretsFile = ../../secrets/mesa-db-01.yaml;

    site.hostIp = "192.168.10.110";
    site.internalIp = "10.10.0.110";

    postgres = {
      ha = {
        enable = true;
        vip = "10.10.0.115";
      };
      admin.enable = true;

      # fleet clients derive from their client.enable flag; only non-fleet sources
      # (admin VLAN for direct psql) need listing here.
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
