{config, ...}: let
  port = 8090;
in {
  lab.topology.routes = [
    {
      host = "np.${config.lab.site.domain}";
      inherit port;
    }
  ];

  sops.secrets."apps/lastfm_api_key" = {};

  sops.templates."nowplaying.env".content = ''
    LASTFM_API_KEY=${config.sops.placeholder."apps/lastfm_api_key"}
  '';

  services.nowplaying = {
    enable = true;
    lastfmUser = "tetrafox_";
    # caddy proxies to the internal IP
    host = config.lab.site.internalIp;
    inherit port;
    environmentFile = config.sops.templates."nowplaying.env".path;
  };
}
