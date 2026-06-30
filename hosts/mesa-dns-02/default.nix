# mesa-dns-02: the other half of the mesa resolver pair. identical unbound config to
# mesa-dns-01 (stateless HA -- both nodes serve the same answers); differs only in hostname,
# IP, and secrets. see mesa-dns-01 for the full rationale.
{
  lib,
  username,
  modules,
  ...
}: {
  imports = [
    ./monitoring.nix

    modules.platform.proxmox-vm.system # qemu-guest + virtio initrd
    modules.platform.disko.proxmox-vm # boot-disk layout (scsi0)
    modules.meta.profiles.server.system

    # the mesa-dns site layer (the mesa zone + blocklists), which imports the generic bind module
    modules.sites.mesa-dns
  ];

  # no modules.platform.sops.system: the resolver decrypts nothing. see mesa-dns-01.

  networking.hostName = "mesa-dns-02";
  lab.site.hostIp = "192.168.10.161";
  # VRRP heartbeat rides ens19 (isolated), .53 VIP stays on ens18. see mesa-dns-01.
  lab.site.internalIp = "10.10.0.161";

  # ask itself, never the router -- see mesa-dns-01 for why (the Technitium forwarding loop).
  networking.nameservers = lib.mkForce ["127.0.0.1"];

  # zone + RPZ built in modules.services.bind.system; this host only flips enable + VIP.
  lab.bind.enable = true;

  lab.bind.ha = {
    enable = true;
    vip = "192.168.10.53";
  };

  systemd.tmpfiles.rules = ["d /var/lib/mesa 0755 root root -"];

  system.stateVersion = "26.11";
}
