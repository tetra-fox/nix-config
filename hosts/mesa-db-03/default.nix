# mesa-db-03: third node of the HA postgres cluster (Patroni + etcd + HAProxy + keepalived).
# see mesa-db-02 for the shared design -- all three db nodes declare the same lab.postgres.ha
# config and the same roles; this file differs only in hostname + IPs.
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

  lab.sops.secretsFile = ../../secrets/mesa-db-03.yaml;

  networking.hostName = "mesa-db-03";
  lab.site.hostIp = "192.168.10.112";
  lab.site.internalIp = "10.10.0.112"; # isolated internal VLAN (ens19); HA traffic rides this

  lab.postgres = {
    ha = {
      enable = true;
      vip = "10.10.0.115"; # the floating endpoint clients reach
    };
    admin.enable = true;

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
