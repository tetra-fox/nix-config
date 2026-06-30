# mesa-edge-01: the mesa site's ingress tier. runs caddy (TLS termination, DNS-01 ACME,
# fail2ban) and reverse-proxies every published service. every upstream is remote and
# derived from site-topology (auth/stats/jellyfin/np) or an external IP (HAOS, AdGuard,
# proxmox), so the Caddyfile never hardcodes which box runs what.
{
  username,
  modules,
  ...
}: {
  imports = [
    ./monitoring.nix

    modules.proxmox-vm.system # qemu-guest + virtio initrd
    modules.disko.proxmox-vm # boot-disk layout (scsi0)
    modules.profiles.server.system

    modules.caddy.system
    modules.sops.system
  ];

  lab.sops.secretsFile = ../../secrets/mesa-edge-01.yaml;

  networking.hostName = "mesa-edge-01";
  lab.site.hostIp = "192.168.10.150";
  lab.site.internalIp = "10.10.0.150"; # isolated internal VLAN (ens19)

  lab.caddy.caddyfile = ./files/caddy/Caddyfile;

  # join the edge VIP (the other half is on edge-02). the VIP is on the server VLAN; the
  # router forwards 443/80 to it and the AdGuard wildcard points at it. keepalived floats it.
  lab.caddy.ha = {
    enable = true;
    vip = "192.168.10.155";
  };

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = ["wheel"];
  };

  system.stateVersion = "26.11";
}
