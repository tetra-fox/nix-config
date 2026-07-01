# peer-list and priority derivation is NOT here on purpose: callers differ (db indexes by
# hostname, edge/dns sort by IP; db/dns peer on internalIp, edge on hostIp), and folding it in
# would change the default VIP holder. each caller resolves unicastSrcIp/unicastPeers/priority.
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

    # keepalived allows the VRRP heartbeat interface and the VIP's interface to differ (dns runs
    # VRRP on an isolated ens19 but parks its VIP on ens18 where clients reach it).
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
    # two hosts sharing an IP get the same priority and fight over the VIP; that surfaces here
    # as unicastSrcIp landing in its own peer list, so catch it at eval instead of runtime.
    assertions = [
      {
        assertion = !(lib.elem cfg.unicastSrcIp cfg.unicastPeers);
        message = "lab.vrrp: unicastSrcIp (${cfg.unicastSrcIp}) is also in unicastPeers -- two hosts likely share an IP, which would tie their VRRP priority and fight over the VIP.";
      }
    ];

    # nixpkgs writes enable_script_security without creating the keepalived_script user it needs;
    # missing that user, keepalived silently ignores the track and the VIP never moves. create it.
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
        # weight 0 forces FAULT (releases the VIP) on failure; a weighted script only nudges
        # priority and fails to fail over when the holder still outranks the peer.
        weight = 0;
      };

      vrrpInstances.${cfg.instanceName} = {
        interface = cfg.vrrpInterface;
        virtualRouterId = cfg.virtualRouterId;
        priority = cfg.priority;
        # all-BACKUP + noPreempt: a recovered node doesn't steal the VIP back and flap.
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

    networking.firewall.extraInputRules = ''
      iifname "${cfg.vrrpInterface}" ip protocol vrrp accept
    '';
  };
}
