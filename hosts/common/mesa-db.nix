# shared by mesa-db-01/02/03. all three nodes declare the same lab.postgres.ha config
# and roles on purpose: any node can be the leader, so each must be able to bootstrap
# and own the databases. host files keep only their IPs and sops yaml.
{
  config,
  lib,
  modules,
  topo,
  ...
}: {
  imports = [
    modules.profiles.server.system

    modules.services.postgres-ha.system
  ];

  lab.postgres = {
    ha = {
      enable = true;
      vip = "10.10.0.115";
    };
    admin.enable = true;

    # trusted-VLAN direct psql; fleet clients are derived from their client.enable flag.
    extraAllowedCidrs = [config.lab.net.trustedCidr];

    # the arr role spec comes off the arr host via the registry, so nothing arr-shaped
    # is restated here
    roles =
      {
        authentik = {
          passwordSecret = "auth/pg_pass";
          owns = ["authentik"];
        };
      }
      // lib.optionalAttrs (topo.arrDbRole != null) {
        ${topo.arrDbRole.name} = {inherit (topo.arrDbRole) passwordSecret owns;};
      };
  };

  system.stateVersion = "26.11";
}
