# mesa-db-01: the mesa site's data tier. runs the postgres server for the whole site --
# authentik (auth-01) and the arrs (svc-01) connect here. clients find it via the
# site-topology dbServerIp derive (lab.postgres.server.enable below is the flag that
# derive keys on), so nothing hardcodes this box's address.
#
# db-01 owns the databases the arrs + authentik use, but doesn't run those services. the
# arr db list is read from svc-01's published lab.arrStack.databases (single source in the
# arr-stack), so it can't drift from the actual arr set. authentik's db is a fixed name.
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

    modules.proxmox-vm.system # qemu-guest + virtio initrd
    modules.disko.proxmox-vm # boot-disk layout (scsi0); single disk
    modules.profiles.server.system

    modules.postgres.system
    modules.sops.system
  ];

  lab.sops.secretsFile = ../../secrets/mesa-db-01.yaml;

  networking.hostName = "mesa-db-01";
  lab.site.hostIp = "192.168.10.245";
  lab.site.internalIp = "10.10.0.245"; # isolated internal VLAN (ens19)

  lab.postgres = {
    server.enable = true; # this host IS the site's db server (the derive points here)
    openFirewall = true; # 5432
    admin.enable = true; # superuser for dbeaver/psql

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

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = ["wheel"];
  };

  system.stateVersion = "26.11";
}
