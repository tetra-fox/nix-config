{
  config,
  lib,
  modules,
  nixosConfigurations,
  ...
}: let
  topo = import modules.meta.lib.site-topology {inherit lib;} {
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
