# resolver HA: derive the dns-specific peer list + priority and health check, hand them to
# lab.vrrp (the shared keepalived scaffolding in modules.services.vrrp.system).
{
  config,
  lib,
  pkgs,
  nixosConfigurations,
  modules,
  topo,
  ...
}: let
  cfg = config.lab.bind;
  inherit (cfg) ha;

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
    assertions = [
      {
        assertion = selfInternalIp != null;
        message = "lab.bind.ha.enable requires lab.site.internalIp (the v4 VRRP heartbeat rides the internal VLAN).";
      }
    ];

    # the static ULA that anchors the v6 VIP: it's the v6 heartbeat source and the address the
    # VIP is a sibling of. only on a dual-stack site (ha.hostV6 set); mesa leaves it null.
    networking.interfaces.${config.lab.site.serverInterface}.ipv6.addresses = lib.mkIf (ha.hostV6 != null) [
      {
        address = ha.hostV6;
        prefixLength = 64;
      }
    ];

    lab.vrrp = {
      enable = true;
      inherit (ha) vip;
      vrrpInterface = config.lab.site.internalInterface; # heartbeat on the isolated VLAN
      vipInterface = config.lab.site.serverInterface; # but the VIP is client-facing, on the server VLAN
      inherit (ha) virtualRouterId;
      priority = 110 - (selfIdx * 5);
      unicastSrcIp = selfInternalIp;
      unicastPeers = otherDnsInternalIps;
      instanceName = "bindvip";

      # v6 VIP (dual-stack sites only). the v6 instance can't share the v4 one, and its heartbeat
      # rides ens18 (where the v6 addresses live), sourced from this host's static ULA. vrid 63 =
      # the v6 counterpart to the v4 53, distinct so the two instances don't collide.
      inherit (ha) vip6;
      virtualRouterId6 =
        if ha.vip6 != null
        then ha.virtualRouterId6
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
