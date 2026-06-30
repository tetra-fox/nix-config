# mesa-edge-02: second ingress node. caddy is stateless, so this is a clone of edge-01 --
# same derived Caddyfile, same upstreams, its own ACME certs (DNS-01, no shared storage).
# keepalived floats the VIP (lab.caddy.ha.vip) across edge-01/02; the router forwards 443/80
# to the VIP and the AdGuard wildcard points at it, so neither box's own IP is the front door.
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

  lab.sops.secretsFile = ../../secrets/mesa-edge-02.yaml;

  networking.hostName = "mesa-edge-02";
  lab.site.hostIp = "192.168.10.151";
  lab.site.internalIp = "10.10.0.151"; # isolated internal VLAN (ens19)

  # same Caddyfile as edge-01 (every upstream derives from topology, so it's host-agnostic)
  lab.caddy.caddyfile = ../mesa-edge-01/files/caddy/Caddyfile;

  # join the edge VIP (the other half is on edge-01). the VIP is on the server VLAN.
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
