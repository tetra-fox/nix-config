# shared by mesa-db-01/02/03. all three nodes declare the same lab.postgres.ha config
# and roles on purpose: any node can be the leader, so each must be able to bootstrap
# and own the databases. host files keep only their IPs and sops yaml.
{
  config,
  modules,
  topo,
  ...
}: let
  arrDbs = topo.arrDatabases;
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

    # trusted-VLAN direct psql; fleet clients are derived from their client.enable flag.
    extraAllowedCidrs = [config.lab.net.trustedCidr];

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
