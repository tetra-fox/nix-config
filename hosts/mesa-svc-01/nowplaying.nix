{
  config,
  lib,
  fleet,
  topo,
  ...
}: let
  edgeIps = topo.edgeHostIps;
  allowFrom = import fleet.nft {inherit lib;};
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

  networking.firewall.extraInputRules = lib.mkIf (edgeIps != []) (allowFrom edgeIps [8090]);
}
