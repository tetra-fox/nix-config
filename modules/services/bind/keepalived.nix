# resolver HA: derive the dns-specific peer list + priority and health check, hand them to
# lab.vrrp (the shared keepalived scaffolding in modules.services.vrrp.system).
{
  config,
  lib,
  pkgs,
  nixosConfigurations,
  modules,
  fleet,
  ...
}: let
  cfg = config.lab.bind;
  inherit (cfg) ha;

  topo = import fleet.topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };

  selfInternalIp = config.lab.site.internalIp;
  allDnsInternalIps =
    lib.sort (a: b: a < b)
    (lib.filter (i: i != null)
      (map (name: nixosConfigurations.${name}.config.lab.site.internalIp or null)
        (topo.hostsProviding "dns")));
  otherDnsInternalIps = lib.filter (ip: ip != selfInternalIp) allDnsInternalIps;
  selfIdx = lib.lists.findFirstIndex (i: i == selfInternalIp) 0 allDnsInternalIps;

  # the other resolvers' v6 heartbeat sources (their static ULAs), for the v6 VRRP instance.
  # only populated on a dual-stack site that set ha.vip6 + ha.hostV6.
  otherDnsV6 =
    lib.filter (v6: v6 != null && v6 != ha.hostV6)
    (map (name: nixosConfigurations.${name}.config.lab.bind.ha.hostV6 or null)
      (topo.hostsProviding "dns"));
in {
  imports = [modules.services.vrrp.system];

  config = lib.mkIf (cfg.enable && ha.enable) {
    # the static ULA that anchors the v6 VIP: it's the v6 heartbeat source and the address the
    # VIP is a sibling of. only on a dual-stack site (ha.hostV6 set); mesa leaves it null.
    networking.interfaces.ens18.ipv6.addresses = lib.mkIf (ha.hostV6 != null) [
      {
        address = ha.hostV6;
        prefixLength = 64;
      }
    ];

    lab.vrrp = {
      enable = true;
      inherit (ha) vip;
      vrrpInterface = "ens19"; # heartbeat on the isolated VLAN
      vipInterface = "ens18"; # but the VIP is client-facing, on the server VLAN
      virtualRouterId = 53; # must be unique per L2 segment; 51 = db, also on ens19
      priority = 110 - (selfIdx * 5);
      unicastSrcIp = selfInternalIp;
      unicastPeers = otherDnsInternalIps;
      instanceName = "bindvip";

      # v6 VIP (dual-stack sites only). the v6 instance can't share the v4 one, and its heartbeat
      # rides ens18 (where the v6 addresses live), sourced from this host's static ULA. vrid 63 =
      # the v6 counterpart to the v4 53, distinct so the two instances don't collide.
      vip6 = ha.vip6;
      virtualRouterId6 =
        if ha.vip6 != null
        then 63
        else null;
      unicastSrcIp6 = ha.hostV6;
      unicastPeers6 = otherDnsV6;

      healthCheck = {
        name = "chk_bind";
        # query the local internal view (no recursion) so an upstream blip can't false-fail it.
        script = ''${pkgs.dnsutils}/bin/dig +short +tries=1 +time=2 @127.0.0.1 ${cfg.zone.name} A'';
      };
    };
  };
}
