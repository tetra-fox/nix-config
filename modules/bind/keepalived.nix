# resolver HA: float the .53 VIP across the mesa dns hosts. the keepalived scaffolding lives in
# modules.vrrp.system (shared with the db + edge clusters); this module only derives the dns-
# specific peer list + priority and the health check, then hands them to lab.vrrp.
#
# the VRRP heartbeat rides ens19 (isolated VLAN, peers are internalIps) like the db cluster; the
# managed .53 VIP lands on ens18 (server VLAN) where clients/router reach it.
{
  config,
  lib,
  pkgs,
  nixosConfigurations,
  modules,
  ...
}: let
  cfg = config.lab.bind;
  ha = cfg.ha;

  topo = import modules.lib.site-topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };

  # peers = the OTHER dns hosts' internal-VLAN IPs (VRRP rides ens19). isDnsHost keys on
  # services.bind.enable (an input flag), the same no-recursion discipline the edge derive uses.
  selfInternalIp = config.lab.site.internalIp;
  allDnsInternalIps =
    lib.sort (a: b: a < b)
    (lib.filter (i: i != null)
      (map (name: nixosConfigurations.${name}.config.lab.site.internalIp or null)
        (topo.hostsWhere topo.isDnsHost)));
  otherDnsInternalIps = lib.filter (ip: ip != selfInternalIp) allDnsInternalIps;
  selfIdx = lib.lists.findFirstIndex (i: i == selfInternalIp) 0 allDnsInternalIps;
in {
  imports = [modules.vrrp.system];

  config = lib.mkIf (cfg.enable && ha.enable) {
    lab.vrrp = {
      enable = true;
      vip = ha.vip;
      vrrpInterface = "ens19"; # heartbeat on the isolated VLAN
      vipInterface = "ens18"; # but the VIP is client-facing, on the server VLAN
      virtualRouterId = 53; # 51 = db (also on ens19), 52 = edge; 53 free + mnemonic for .53
      priority = 110 - (selfIdx * 5); # lowest-IP dns host is the default holder
      unicastSrcIp = selfInternalIp;
      unicastPeers = otherDnsInternalIps;
      instanceName = "bindvip";
      healthCheck = {
        name = "chk_bind";
        # query the LOCAL listener for the split-horizon apex, which bind answers from its
        # internal view (no recursion, so an upstream blip can't false-fail it). dig @127.0.0.1
        # needs no credentials, so it works as the unprivileged keepalived_script user, and it
        # exits non-zero when named is down.
        script = ''${pkgs.dnsutils}/bin/dig +short +tries=1 +time=2 @127.0.0.1 mesa.tetra.cool A'';
      };
    };
  };
}
