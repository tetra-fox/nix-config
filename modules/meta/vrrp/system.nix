# shared keepalived/VRRP scaffolding for the mesa HA clusters (db, edge, dns). each of those
# floats a service VIP across a pair/trio of stateless-at-the-VIP-layer nodes; the keepalived
# config they need is identical except for a handful of values (which interface, which VIP,
# which health check, the vrid). this module owns the invariant parts and takes the rest as
# inputs, so the three service modules stop copy-pasting the same vrrpInstance + the same
# keepalived_script-user footgun comment.
#
# what's NOT here, on purpose: the peer-list and priority DERIVATION. db indexes nodes by
# hostname order via ipsWhere, edge/dns sort by IP; db/dns peer on internalIp, edge on hostIp.
# folding that into one "derive" would either change which node holds the VIP by default (a
# silent failover regression) or need so many toggles it's not simpler. so each caller computes
# unicastSrcIp/unicastPeers/priority itself and hands them in already-resolved.
{
  config,
  lib,
  ...
}: let
  cfg = config.lab.vrrp;
in {
  options.lab.vrrp = {
    enable = lib.mkEnableOption "keepalived VRRP for an HA service VIP on this host";

    vip = lib.mkOption {
      type = lib.types.str;
      description = "the floating virtual IP this node may hold (e.g. 192.168.10.53).";
    };

    # the VRRP heartbeat interface and the interface the VIP is parked on can differ: db floats
    # both on ens19, dns runs VRRP on ens19 (isolated) but parks the .53 VIP on ens18 (where
    # clients reach it). keepalived allows the instance interface and the virtualIp dev to differ.
    vrrpInterface = lib.mkOption {
      type = lib.types.str;
      description = "interface the VRRP instance runs on (the heartbeat path).";
      example = "ens19";
    };

    vipInterface = lib.mkOption {
      type = lib.types.str;
      description = "interface the VIP is parked on (where clients reach it). often = vrrpInterface.";
      example = "ens18";
    };

    virtualRouterId = lib.mkOption {
      type = lib.types.int;
      description = ''
        VRRP router id, unique per L2 segment. the mesa allocations: 51 = db, 52 = edge, 53 = dns.
        two instances sharing a vrid on the same segment will fight over the VIP.
      '';
    };

    # already-resolved by the caller (see the module comment for why the derivation isn't here).
    priority = lib.mkOption {
      type = lib.types.int;
      description = "this node's VRRP priority. higher = preferred holder. callers use 110 - idx*5.";
    };

    unicastSrcIp = lib.mkOption {
      type = lib.types.str;
      description = "this node's source IP for unicast VRRP (on vrrpInterface's subnet).";
    };

    unicastPeers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "the other nodes' IPs for unicast VRRP (this node excluded).";
    };

    instanceName = lib.mkOption {
      type = lib.types.str;
      description = "keepalived vrrpInstance name (e.g. bindvip). just a label, unique per host.";
    };

    healthCheck = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "track-script name (e.g. chk_bind). unique per host.";
      };
      script = lib.mkOption {
        type = lib.types.str;
        description = ''
          the health-check command. exit non-zero -> this node drops the VIP. runs as the
          unprivileged keepalived_script user, so it must not need root/credentials.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # enableScriptSecurity runs track-scripts as a non-root user, but the nixpkgs module writes
    # enable_script_security WITHOUT creating the keepalived_script user it then demands. missing
    # -> keepalived silently ignores the track entirely and the VIP never moves on service death.
    # create the user. (this exact footgun bit the db and edge clusters before it was understood.)
    users.users.keepalived_script = {
      isSystemUser = true;
      group = "keepalived_script";
      description = "runs keepalived track scripts under enableScriptSecurity";
    };
    users.groups.keepalived_script = {};

    services.keepalived = {
      enable = true;
      enableScriptSecurity = true;

      vrrpScripts.${cfg.healthCheck.name} = {
        script = cfg.healthCheck.script;
        interval = 2;
        fall = 2;
        rise = 2;
        # weight 0 = weightless: a failure puts the instance into FAULT, which releases the VIP
        # unconditionally. a weighted script only nudges priority, which fails to fail over when
        # the holder's effective priority still outranks the peer -- the bug all three clusters
        # would hit with a nonzero weight.
        weight = 0;
      };

      vrrpInstances.${cfg.instanceName} = {
        interface = cfg.vrrpInterface;
        virtualRouterId = cfg.virtualRouterId;
        priority = cfg.priority;
        # all-BACKUP + noPreempt: a recovered node doesn't steal the VIP back and flap; whoever
        # holds it keeps it until it actually dies.
        state = "BACKUP";
        noPreempt = true;
        # unicast VRRP -- no reliance on L2 multicast on the SDN bridge.
        unicastSrcIp = cfg.unicastSrcIp;
        unicastPeers = cfg.unicastPeers;
        virtualIps = [
          {
            addr = "${cfg.vip}/24";
            dev = cfg.vipInterface;
          }
        ];
        trackScripts = [cfg.healthCheck.name];
      };
    };

    # VRRP (protocol 112) between the keepalived peers, on the heartbeat interface.
    networking.firewall.extraInputRules = ''
      iifname "${cfg.vrrpInterface}" ip protocol vrrp accept
    '';
  };
}
