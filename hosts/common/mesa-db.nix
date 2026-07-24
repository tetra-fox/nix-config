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

    modules.services.media-mount.system
    modules.services.postgres-ha.system
  ];

  # the store box exports megamax/backup/postgres to each db node as that client's fsid=0
  # root, so the generic store mount surfaces the dump dataset here. no gatedServices: the
  # dump unit orders on the mount itself (RequiresMountsFor)
  lab.storage.mediaMount = {
    enable = true;
    mountpoint = "/mnt/pgbackup";
    gatedServices = [];
  };

  lab.postgres = {
    ha = {
      enable = true;
      vip = "10.10.0.115";
    };
    admin.enable = true;

    # nightly leader dump onto the store box; restic ships it offsite at 14:30
    backup = {
      enable = true;
      dir = "/mnt/pgbackup";
    };

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
