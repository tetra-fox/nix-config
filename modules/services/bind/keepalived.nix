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
in {
  imports = [modules.services.vrrp.system];

  config = lib.mkIf (cfg.enable && ha.enable) {
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
      healthCheck = {
        name = "chk_bind";
        # query the local internal view (no recursion) so an upstream blip can't false-fail it.
        script = ''${pkgs.dnsutils}/bin/dig +short +tries=1 +time=2 @127.0.0.1 ${cfg.zone.name} A'';
      };
    };
  };
}
