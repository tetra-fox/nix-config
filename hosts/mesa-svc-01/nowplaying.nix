{
  config,
  lib,
  modules,
  nixosConfigurations,
  ...
}: let
  # caddy lives on the edge box now, so nowplaying has to bind svc-01's site IP (not
  # loopback) for the proxy to reach it. open 8090 to the edge host(s) only -- the sole
  # legitimate clients. derived from site-topology: every edge box's real IP, since caddy
  # proxies FROM its own box (not the VIP), so with two edge boxes both are valid sources.
  topo = import modules.lib.site-topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };
  edgeIps = topo.edgeHostIps;
in {
  sops.secrets."apps/lastfm_api_key" = {};

  sops.templates."nowplaying.env".content = ''
    LASTFM_API_KEY=${config.sops.placeholder."apps/lastfm_api_key"}
  '';

  services.nowplaying = {
    enable = true;
    lastfmUser = "tetrafox_";
    # bind the INTERNAL-VLAN IP: caddy's npUpstream derives to this host's internal IP (ipOf
    # prefers internalIp for east-west), so np must listen there. binding the server IP instead
    # is why np.<site> 502'd -- caddy proxied to the internal IP with nothing listening on it.
    host = config.lab.site.internalIp;
    port = 8090;
    environmentFile = config.sops.templates."nowplaying.env".path;
  };

  # open 8090 to the edge (caddy) host(s) only, source-scoped -- one accept per edge box.
  # needs the nftables backend (base profile enables it fleet-wide).
  networking.firewall.extraInputRules = lib.mkIf (edgeIps != []) (
    lib.concatMapStringsSep "\n" (ip: "ip saddr ${ip} tcp dport 8090 accept") edgeIps
  );
}
