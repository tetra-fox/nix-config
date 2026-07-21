# host-role boilerplate shared by every site's bind resolver (mesa-dns-01/02, fairlane-dns-01/02):
# a stateless bind node in a keepalived HA pair that answers itself. the per-site zone data and
# dual-stack knobs live in the site module (modules.sites.{mesa,fairlane}-dns), which the host
# imports alongside this; the host file keeps only its IPs (and fairlane's v6 VIP/host addresses).
{
  config,
  lib,
  modules,
  ...
}: {
  imports = [modules.profiles.server.system];

  # resolve to self, not the router (routing through the router is a forwarding loop). mkForce
  # overrides the site facts, which point every resolver at the router.
  networking.nameservers = lib.mkForce ["127.0.0.1"];

  lab.bind = {
    enable = true;
    # dns is stateless, so HA is real on 2 nodes: -01 and -02 sit on different proxmox hosts and
    # the VIP flips. VRRP heartbeat rides ens19 (the internal leg), the .53 VIP stays on ens18.
    ha = {
      enable = true;
      vip = "192.168.10.53";
    };
  };

  # no storage.nix here, so create the siteData root itself
  systemd.tmpfiles.rules = ["d ${config.lab.site.dataDir} 0755 root root -"];

  system.stateVersion = "26.11";
}
