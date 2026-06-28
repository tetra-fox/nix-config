# mesa-mon-01: the mesa site's monitoring server. lightweight proxmox VM that runs
# prometheus + loki + grafana and scrapes every mesa-svc-NN agent. no media/service
# workload -- kept separate so a busy/wedged svc box can't take monitoring down with it.
{
  config,
  username,
  modules,
  ...
}: {
  imports = [
    ./monitoring.nix

    modules.disko.proxmox-vm
    modules.profiles.server.system

    modules.sops.system
  ];

  lab.sops.secretsFile = ../../secrets/mesa-mon-01.yaml;

  # prometheus/loki/grafana state lives here (one backup target). mon-01 is a plain
  # single-disk VM, no media mount, so this is just a dir on the root fs.
  _module.args.siteData = "/var/lib/mesa";
  systemd.tmpfiles.rules = ["d /var/lib/mesa 0755 root root -"];

  networking = {
    hostName = "mesa-mon-01";
    # ens18 = server vlan (LAN-routable, default route). single-NIC, same as svc-01.
    useDHCP = false;
    defaultGateway = "192.168.10.1";
    nameservers = ["192.168.10.53"];

    interfaces.ens18 = {
      mtu = 9000; # jumbo frames; milkfish bridge + switch are 9000 end-to-end
      ipv4.addresses = [
        {
          address = "192.168.10.207";
          prefixLength = 24;
        }
      ];
    };
  };

  # proxmox guest under milkfish; single vNIC on the server vlan
  topology.self.parent = "milkfish";

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = ["wheel"];
  };

  system.stateVersion = "26.11";
}
