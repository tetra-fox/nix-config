{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lab.netnsVpn;

  netns = "vpn";
  netnsPath = "/var/run/netns/${netns}";
  hostVeth = "veth-vpn-host";
  nsVeth = "veth-vpn-ns";
  hostVethIp = "10.200.200.1";
  nsVethIp = "10.200.200.2";
  vethCidr = "30";

  netnsEnv = {
    NETNS = netns;
    HOST_VETH = hostVeth;
    NS_VETH = nsVeth;
    HOST_VETH_IP = hostVethIp;
    NS_VETH_IP = nsVethIp;
    VETH_CIDR = vethCidr;
  };

  secret = key: config.sops.secrets."${cfg.secretPrefix}/${key}".path;
in {
  options.lab.netnsVpn = {
    mtu = lib.mkOption {
      type = lib.types.int;
      default = 1320; # AirVPN
    };

    secretPrefix = lib.mkOption {
      type = lib.types.str;
      default = "arr";
    };
  };

  config = {
    _module.args = {inherit netns netnsPath nsVethIp hostVethIp;};

    sops.secrets = {
      "${cfg.secretPrefix}/wg_private_key" = {};
      "${cfg.secretPrefix}/wg_peer_public_key" = {};
      "${cfg.secretPrefix}/wg_preshared_key" = {};
      "${cfg.secretPrefix}/wg_peer_endpoint" = {};
      "${cfg.secretPrefix}/wg_address" = {};
    };

    systemd.services = {
      netns-vpn = {
        description = "vpn network namespace + veth bridge to main ns";
        wantedBy = ["multi-user.target"];
        before = ["network-online.target"];
        path = [pkgs.iproute2];
        environment = netnsEnv;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "netns-up" (builtins.readFile ./netns-up.sh);
          ExecStop = pkgs.writeShellScript "netns-down" (builtins.readFile ./netns-down.sh);
        };
      };

      wg-vpn = {
        description = "wireguard interface inside vpn netns";
        after = ["netns-vpn.service"];
        requires = ["netns-vpn.service"];
        bindsTo = ["netns-vpn.service"];
        wantedBy = ["multi-user.target"];
        path = [pkgs.iproute2 pkgs.wireguard-tools];
        environment = netnsEnv // {WG_MTU = toString cfg.mtu;};
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          LoadCredential = [
            "wg_private_key:${secret "wg_private_key"}"
            "wg_peer_public_key:${secret "wg_peer_public_key"}"
            "wg_preshared_key:${secret "wg_preshared_key"}"
            "wg_peer_endpoint:${secret "wg_peer_endpoint"}"
            "wg_address:${secret "wg_address"}"
          ];
          ExecStart = pkgs.writeShellScript "wg-up" (builtins.readFile ./wg-up.sh);
          ExecStop = pkgs.writeShellScript "wg-down" (builtins.readFile ./wg-down.sh);
        };
      };
    };
  };
}
