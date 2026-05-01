{config, ...}: {
  sops.secrets."apps/lastfm_api_key" = {};

  sops.templates."nowplaying.env".content = ''
    LASTFM_API_KEY=${config.sops.placeholder."apps/lastfm_api_key"}
  '';

  services.nowplaying = {
    enable = true;
    lastfmUser = "tetrafox_";
    port = 8090;
    environmentFile = config.sops.templates."nowplaying.env".path;
  };
}
