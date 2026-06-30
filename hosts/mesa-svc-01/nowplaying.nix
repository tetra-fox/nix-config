{
  config,
  lib,
  modules,
  nixosConfigurations,
  ...
}: let
  # caddy lives on the edge box now, so nowplaying has to bind svc-01's site IP (not
  # loopback) for the proxy to reach it. open 8090 to the edge host only -- it's the sole
  # legitimate client. both derived from site-topology (the host running caddy).
  topo = import modules.lib.site-topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };
  edgeIp = topo.edgeHostIp;
in {
  sops.secrets."apps/lastfm_api_key" = {};

  sops.templates."nowplaying.env".content = ''
    LASTFM_API_KEY=${config.sops.placeholder."apps/lastfm_api_key"}
  '';

  services.nowplaying = {
    enable = true;
    lastfmUser = "tetrafox_";
    host = config.lab.site.hostIp; # bind the site IP so edge-01's caddy can reach it
    port = 8090;
    environmentFile = config.sops.templates."nowplaying.env".path;
  };

  # open 8090 to the edge (caddy) host only, source-scoped. needs the nftables backend
  # (base profile enables it fleet-wide).
  networking.firewall.extraInputRules = lib.mkIf (edgeIp != null) ''
    ip saddr ${edgeIp} tcp dport 8090 accept
  '';
}
