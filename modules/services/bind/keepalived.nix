{
  config,
  lib,
  pkgs,
  nixosConfigurations,
  modules,
  topo,
  caps,
  ...
}: let
  cfg = config.lab.bind;
  inherit (cfg) ha;

  selfInternalIp = config.lab.site.internalIp;
  allDnsInternalIps =
    lib.sort (a: b: a < b)
    (lib.filter (i: i != null)
      (map (name: nixosConfigurations.${name}.config.lab.site.internalIp or null)
        (topo.hostsProviding caps.dns.name)));
  otherDnsInternalIps = lib.filter (ip: ip != selfInternalIp) allDnsInternalIps;
  selfIdx = lib.lists.findFirstIndex (i: i == selfInternalIp) 0 allDnsInternalIps;

  # empty unless the site is dual-stack (ha.hostV6 set)
  otherDnsV6 =
    lib.filter (v6: v6 != null && v6 != ha.hostV6)
    (map (name: nixosConfigurations.${name}.config.lab.bind.ha.hostV6 or null)
      (topo.hostsProviding caps.dns.name));
in {
  imports = [modules.services.vrrp.system];

  config = lib.mkIf (cfg.enable && ha.enable) {
    assertions = [
      {
        assertion = selfInternalIp != null;
        message = "lab.bind.ha.enable requires lab.site.internalIp (the v4 VRRP heartbeat rides the internal VLAN).";
      }
    ];

    # v6 heartbeat source, and the address the v6 VIP sits next to
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
      priorityIndex = selfIdx;
      unicastSrcIp = selfInternalIp;
      unicastPeers = otherDnsInternalIps;
      instanceName = "bindvip";

      # v6 can't share the v4 instance, so it gets its own vrid
      inherit (ha) vip6;
      virtualRouterId6 =
        if ha.vip6 != null
        then ha.virtualRouterId6
        else null;
      unicastSrcIp6 = ha.hostV6;
      unicastPeers6 = otherDnsV6;

      healthCheck = {
        name = "chk_bind";
        # authoritative zone, no recursion, so an upstream blip can't fail it
        script = ''${pkgs.dnsutils}/bin/dig +short +tries=1 +time=2 @127.0.0.1 ${cfg.zone.name} A'';
      };
    };
  };
}
