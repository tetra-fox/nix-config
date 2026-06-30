# resolver HA: keepalived floats a VIP across the mesa dns hosts on the server VLAN. bind is
# stateless here (each node recurses independently and serves the same zones + RPZ), so like the
# edge caddy HA there's no leader/quorum/etcd -- the VIP just lands on a live resolver. the
# router's upstream DNS points at the VIP, so every node declares the same lab.bind.ha.vip.
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

  # the VRRP heartbeat rides the isolated internal VLAN (ens19), like the db cluster: the peer
  # addresses and unicastSrcIp are internalIps (10.10.0.x). only the managed VIP lands on ens18
  # (the server VLAN), where clients and the router reach it. isDnsHost keys on services.bind.enable
  # (an input flag), the same no-recursion discipline the edge derive uses with services.caddy.
  selfInternalIp = config.lab.site.internalIp;
  allDnsInternalIps =
    lib.sort (a: b: a < b)
    (lib.filter (i: i != null)
      (map (name: nixosConfigurations.${name}.config.lab.site.internalIp or null)
        (topo.hostsWhere topo.isDnsHost)));
  otherDnsInternalIps = lib.filter (ip: ip != selfInternalIp) allDnsInternalIps;
in {
  config = lib.mkIf (cfg.enable && ha.enable) {
    # enableScriptSecurity runs track-scripts as a non-root user, but the nixpkgs module writes
    # enable_script_security WITHOUT creating the keepalived_script user it then demands. missing
    # -> keepalived silently ignores the track and the VIP never moves on resolver death. create
    # the user. (this footgun bit the db and edge clusters.)
    users.users.keepalived_script = {
      isSystemUser = true;
      group = "keepalived_script";
      description = "runs keepalived track scripts under enableScriptSecurity";
    };
    users.groups.keepalived_script = {};

    services.keepalived = {
      enable = true;
      enableScriptSecurity = true;

      # health check: query the LOCAL listener for the split-horizon apex, which bind answers
      # from its internal view (no recursion, so an upstream blip can't false-fail it). runs as
      # the unprivileged keepalived_script user, so it must NOT need credentials -- dig @127.0.0.1
      # hits the local socket directly and exits non-zero when named is down, no rndc key needed.
      vrrpScripts.chk_bind = {
        script = ''${pkgs.dnsutils}/bin/dig +short +tries=1 +time=2 @127.0.0.1 mesa.tetra.cool A'';
        interval = 2;
        fall = 2;
        rise = 2;
        # weight 0 = weightless: a failure puts the instance into FAULT and releases the VIP
        # unconditionally. a weighted script only nudges priority, which fails to fail over when
        # the holder still outranks the peer -- the bug both prior clusters hit before weight 0.
        weight = 0;
      };

      vrrpInstances.bindvip = {
        # the VRRP instance runs on ens19 (isolated VLAN) -- heartbeat + election are east-west.
        interface = "ens19";
        # virtualRouterId unique per L2 segment. ens19 also carries the db cluster's vrid 51, so
        # this must differ from 51 there; 53 is free (and mnemonic for the .53 service VIP).
        virtualRouterId = 53;
        # lowest-IP dns host is the default holder; derived from sorted position, not hardcoded.
        priority = let
          idx = lib.lists.findFirstIndex (i: i == selfInternalIp) 0 allDnsInternalIps;
        in
          110 - (idx * 5);
        state = "BACKUP";
        noPreempt = true;
        # VRRP unicast over ens19 (internal IPs).
        unicastSrcIp = selfInternalIp;
        unicastPeers = otherDnsInternalIps;
        # but the managed VIP lands on ens18 -- that's the address clients/router hit, so it must
        # be on the server VLAN. keepalived allows the instance interface and the VIP dev to differ.
        virtualIps = [
          {
            addr = "${ha.vip}/24";
            dev = "ens18";
          }
        ];
        trackScripts = ["chk_bind"];
      };
    };

    # VRRP now rides ens19, so accept the protocol there (not ens18).
    networking.firewall.extraInputRules = ''
      iifname "ens19" ip protocol vrrp accept
    '';
  };
}
