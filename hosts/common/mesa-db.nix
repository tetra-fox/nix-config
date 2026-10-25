# the db config every mesa db node shares, single server or patroni member
{
  config,
  lib,
  modules,
  topo,
  ...
}: {
  imports = [
    modules.profiles.server.system

    modules.services.store-mount.system
    modules.services.postgres.options
  ];

  # the dump unit orders on the mount itself
  lab.storage.mounts."backup/postgres".mountpoint = "/mnt/pgbackup";

  lab.postgres = {
    admin.enable = true;

    backup = {
      enable = true;
      dir = "/mnt/pgbackup";
    };

    extraAllowedCidrs = [config.lab.net.trustedCidr];

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
