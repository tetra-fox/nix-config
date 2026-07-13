{
  config,
  lib,
  modules,
  fleet,
  nixosConfigurations,
  ...
}: let
  topo = import fleet.topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };
  edgeIps = topo.edgeHostIps;
in {
  lab.topology.routes = [
    {
      host = "np.${config.lab.site.domain}";
      port = 8090;
    }
  ];

  sops.secrets."apps/lastfm_api_key" = {};

  sops.templates."nowplaying.env".content = ''
    LASTFM_API_KEY=${config.sops.placeholder."apps/lastfm_api_key"}
  '';

  services.nowplaying = {
    enable = true;
    lastfmUser = "tetrafox_";
    # bind the internal-VLAN IP: caddy proxies to this host's internal IP, so binding the
    # server IP instead 502s (caddy hits the internal IP with nothing listening).
    host = config.lab.site.internalIp;
    port = 8090;
    environmentFile = config.sops.templates."nowplaying.env".path;
  };

  # source-scoped rules need the nftables backend (base profile enables it fleet-wide).
  networking.firewall.extraInputRules = lib.mkIf (edgeIps != []) (
    lib.concatMapStringsSep "\n" (ip: "ip saddr ${ip} tcp dport 8090 accept") edgeIps
  );
}
