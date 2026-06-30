# mesa-dns-01: half of the mesa site's recursive resolver pair. runs unbound (full recursion
# from the roots, DNSSEC, split-horizon mesa.tetra.cool, OISD + VRChat blocklists) and joins
# the keepalived VIP at .53 with mesa-dns-02. replaces the old Technitium box that held .53.
#
# unbound is stateless, so this is the edge-caddy HA model, not the db one: two nodes, a
# floating VIP, no etcd/quorum. whichever node holds .53 answers; the router's upstream DNS
# points at .53 and never has to know which box is live.
{
  lib,
  username,
  modules,
  ...
}: {
  imports = [
    ./monitoring.nix

    modules.proxmox-vm.system # qemu-guest + virtio initrd
    modules.disko.proxmox-vm # boot-disk layout (scsi0)
    modules.profiles.server.system

    # the mesa-dns site layer (the mesa zone + blocklists), which imports the generic bind module
    modules.sites.mesa-dns
  ];

  # no modules.sops.system: the resolver decrypts nothing (bind declares no secrets, and the
  # monitoring/logging agent path gates all its secrets behind the server role). adding sops
  # would only create an unused secrets file to maintain.

  networking.hostName = "mesa-dns-01";
  lab.site.hostIp = "192.168.10.160";
  # the .53 service VIP lives on the server VLAN (ens18) where clients/router reach it, but the
  # keepalived VRRP heartbeat between the two resolvers is VM-to-VM east-west, so it rides the
  # isolated internal VLAN (ens19) like the db cluster does. that needs an internalIp here.
  lab.site.internalIp = "10.10.0.160";

  # the resolver must NOT resolve through the router -- that's the forwarding loop the old
  # Technitium box hit (container -> router -> .53 -> ... -> REFUSED). it asks itself instead.
  # mkForce overrides the mesa site facts, which point every host's resolver at the router.
  networking.nameservers = lib.mkForce ["127.0.0.1"];

  # the split-horizon zone + RPZ blocklists are built in modules.bind.system (they're a site
  # fact, identical on both resolvers), so this host only flips enable + the VIP.
  lab.bind.enable = true;

  # join the .53 resolver VIP (the other half is on dns-02). the router's upstream DNS points
  # here; keepalived floats it to whichever node is alive.
  lab.bind.ha = {
    enable = true;
    vip = "192.168.10.53";
  };

  # plain single-disk VM (no media group); create the siteData root itself
  systemd.tmpfiles.rules = ["d /var/lib/mesa 0755 root root -"];

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = ["wheel"];
  };

  system.stateVersion = "26.11";
}
