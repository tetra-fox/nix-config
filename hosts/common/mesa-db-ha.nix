# identical on all three nodes, any one can be leader and must be able to bootstrap
{modules, ...}: {
  imports = [
    ./mesa-db.nix
    modules.services.postgres-ha.system
  ];

  lab.postgres.ha = {
    enable = true;
    vip = "10.10.0.115";
  };
}
