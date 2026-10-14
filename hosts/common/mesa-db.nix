# identical on all three nodes, any one can be leader and must be able to bootstrap
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

  # no gatedServices, the dump unit orders on the mount itself
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
