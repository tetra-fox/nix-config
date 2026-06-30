# mesa-db-01: first node of the mesa site's HA data tier (Patroni + etcd + HAProxy +
# keepalived). clients reach the cluster via the floating VIP (lab.postgres.ha.vip),
# resolved by the site-topology dbEndpointIp derive; nothing hardcodes which node is primary.
#
# db-01 owns the databases the arrs + authentik use, but doesn't run those services. the
# arr db list is read from svc-01's published lab.arrStack.databases (single source in the
# arr-stack), so it can't drift from the actual arr set. authentik's db is a fixed name.
#
# this was the single-server postgres box before the HA cutover; the old data dir under
# ${siteData}/postgresql stays on disk untouched as a rollback point (Patroni uses a fresh
# dir under ${siteData}/patroni). data was migrated by dump/restore at cutover.
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

  lab.sops.secretsFile = ../../secrets/mesa-db-01.yaml;

  networking.hostName = "mesa-db-01";
  lab.site.hostIp = "192.168.10.110";
  lab.site.internalIp = "10.10.0.110"; # isolated internal VLAN (ens19); HA traffic rides this

  lab.postgres = {
    ha = {
      enable = true;
      vip = "10.10.0.115"; # the floating endpoint clients reach
    };
    admin.enable = true; # superuser for dbeaver/psql (reconciled on the leader)

    # fleet clients (svc-01's arrs via the netns SNAT, auth-01's authentik) are derived
    # from their lab.postgres.client.enable flag -> their hostIp. only non-fleet sources
    # need listing here: the trusted admin VLAN for direct psql.
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
