# callers resolve their own peers and priorityIndex: db indexes by hostname, edge/dns by IP,
# and unifying them would change the default VIP holder
{
  config,
  lib,
  ...
}: let
  cfg = config.lab.vrrp;
  priority = 110 - (cfg.priorityIndex * 5);
in {
  options.lab.vrrp = {
    enable = lib.mkEnableOption "keepalived VRRP for an HA service VIP on this host";

    vip = lib.mkOption {
      type = lib.types.str;
      description = "the floating virtual IP this node may hold (e.g. 192.168.10.53).";
    };

    vipPrefixLength = lib.mkOption {
      type = lib.types.int;
      default = 24;
      description = "prefix length for the VIP's on-link route on vipInterface.";
    };

    vipPrefixLength6 = lib.mkOption {
      type = lib.types.int;
      default = 64;
      description = "prefix length for the v6 VIP's on-link route.";
    };

    # use a ULA when the ISP prefix rotates, a GUA VIP breaks on every prefix change
    vip6 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "optional floating IPv6 VIP (e.g. a ULA fd00:10::53); null = v4-only.";
    };

    virtualRouterId6 = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "vrid for the v6 instance (required when vip6 is set); distinct from the v4 vrid.";
    };

    unicastSrcIp6 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "this node's v6 source for the v6 VRRP heartbeat (the ens18 link-local, fe80::...).";
    };

    unicastPeers6 = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "the other nodes' v6 heartbeat sources (link-locals) for the v6 instance.";
    };

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
        VRRP router id, unique per L2 segment (mesa: 51 db, 52 edge, 53 dns). instances sharing
        a vrid on one segment fight over the VIP. sites on separate segments can reuse ids, two
        sites sharing a segment would need distinct ones.
      '';
    };

    priorityIndex = lib.mkOption {
      type = lib.types.int;
      description = "this node's stable index among its cluster peers (0 = preferred VIP holder); priority derives as 110 - idx*5";
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
    assertions = [
      {
        assertion = !(lib.elem cfg.unicastSrcIp cfg.unicastPeers);
        message = "lab.vrrp: unicastSrcIp (${cfg.unicastSrcIp}) is also in unicastPeers -- two hosts likely share an IP, which would tie their VRRP priority and fight over the VIP.";
      }
      {
        assertion = cfg.vip6 == null || (cfg.virtualRouterId6 != null && cfg.unicastSrcIp6 != null);
        message = "lab.vrrp: vip6 requires both virtualRouterId6 and unicastSrcIp6 (the v6 instance needs its own vrid + a v6 heartbeat source).";
      }
    ];

    # nixpkgs sets enable_script_security without creating this user, and without it keepalived
    # silently ignores the track script so the VIP never moves
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
        # 0 forces FAULT on failure, a weight only nudges priority and the holder can still outrank
        weight = 0;
      };

      vrrpInstances =
        {
          ${cfg.instanceName} = {
            interface = cfg.vrrpInterface;
            inherit (cfg) virtualRouterId;
            inherit priority;
            # all-BACKUP + noPreempt: a recovered node doesn't steal the VIP back
            state = "BACKUP";
            noPreempt = true;
            # no L2 multicast on the SDN bridge
            inherit (cfg) unicastSrcIp;
            inherit (cfg) unicastPeers;
            virtualIps = [
              {
                addr = "${cfg.vip}/${toString cfg.vipPrefixLength}";
                dev = cfg.vipInterface;
              }
            ];
            trackScripts = [cfg.healthCheck.name];
          };
        }
        # keepalived can't mix families in one instance. heartbeat on vipInterface since it has
        # the v6 addresses, same track script so both VIPs drop together
        // lib.optionalAttrs (cfg.vip6 != null) {
          "${cfg.instanceName}6" = {
            interface = cfg.vipInterface;
            virtualRouterId = cfg.virtualRouterId6;
            inherit priority;
            state = "BACKUP";
            noPreempt = true;
            unicastSrcIp = cfg.unicastSrcIp6;
            unicastPeers = cfg.unicastPeers6;
            virtualIps = [
              {
                addr = "${cfg.vip6}/${toString cfg.vipPrefixLength6}";
                dev = cfg.vipInterface;
              }
            ];
            trackScripts = [cfg.healthCheck.name];
          };
        };
    };

    # networkd strips addresses it didn't configure whenever it (re)configures a link, which
    # takes the vip off the holder on a networkd restart. static keeps foreign static addresses
    systemd.network.networks."40-${cfg.vipInterface}".networkConfig.KeepConfiguration = "static";

    networking.firewall.extraInputRules =
      ''
        iifname "${cfg.vrrpInterface}" ip protocol vrrp accept
      ''
      + lib.optionalString (cfg.vip6 != null) ''
        iifname "${cfg.vipInterface}" ip6 nexthdr vrrp accept
      '';
  };
}
