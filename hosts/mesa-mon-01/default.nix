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

    modules.proxmox-vm.system # this host is a proxmox VM (qemu-guest + virtio initrd)
    modules.disko.proxmox-vm # boot-disk layout
    modules.profiles.server.system

    modules.sops.system
  ];

  lab.sops.secretsFile = ../../secrets/mesa-mon-01.yaml;

  # site facts (VLAN/gateway/DNS layout, siteData root, topology parent) come from
  # the `mesa` tag (modules/sites/mesa.nix). this host just declares its own IP.
  networking.hostName = "mesa-mon-01";
  lab.site.hostIp = "192.168.10.207";
  lab.site.internalIp = "10.10.0.207"; # isolated internal VLAN (ens19)

  # mon-01 is a plain single-disk VM (no media group); create the siteData root itself
  systemd.tmpfiles.rules = ["d /var/lib/mesa 0755 root root -"];

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = ["wheel"];
  };

  system.stateVersion = "26.11";
}
