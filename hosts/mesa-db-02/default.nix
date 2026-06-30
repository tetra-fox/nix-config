# mesa-db-02: second node of the HA postgres cluster (Patroni + etcd + HAProxy + keepalived).
# all three db nodes (db-01/02/03) declare the same lab.postgres.ha config and the same roles
# -- any node can be the leader, so each must be able to bootstrap/own the databases. clients
# reach the cluster via the floating VIP (lab.postgres.ha.vip), resolved by the site-topology
# dbEndpointIp derive; nothing hardcodes which node is primary.
#
# the role set (which databases exist + who owns them) is the same single source db-01 uses:
# the arr db list comes from svc-01's published lab.arrStack.databases, authentik's is fixed.
{
  username,
  modules,
  nixosConfigurations,
  ...
}: let
  arrDbs = nixosConfigurations.mesa-svc-01.config.lab.arrStack.databases;
in {
  imports = [
    ./monitoring.nix

    modules.platform.proxmox-vm.system # qemu-guest + virtio initrd
    modules.platform.disko.proxmox-vm # boot-disk layout (scsi0); single disk
    modules.meta.profiles.server.system

    modules.services.postgres-ha.system
    modules.platform.sops.system
  ];

  lab.sops.secretsFile = ../../secrets/mesa-db-02.yaml;

  networking.hostName = "mesa-db-02";
  lab.site.hostIp = "192.168.10.111";
  lab.site.internalIp = "10.10.0.111"; # isolated internal VLAN (ens19); HA traffic rides this

  lab.postgres = {
    ha = {
      enable = true;
      vip = "10.10.0.115"; # the floating endpoint clients reach
    };
    admin.enable = true; # superuser for dbeaver/psql (reconciled on the leader)

    # admin-VLAN direct psql; fleet clients (svc-01 arrs, auth-01) are derived from their
    # client.enable flag. mirrors db-01 -- every HA node shares the same allow-list.
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
