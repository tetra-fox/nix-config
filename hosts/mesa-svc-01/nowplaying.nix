{
  config,
  siteEnvFile,
  ...
}: {
  sops.secrets."apps/lastfm_api_key" = {};

  sops.templates."nowplaying.env" = {
    content = "LASTFM_API_KEY=${config.sops.placeholder."apps/lastfm_api_key"}\n";
    group = "media";
    mode = "0440";
  };

  # custom image; small page with current last.fm playing track.
  virtualisation.oci-containers.containers.nowplaying = {
    image = "ghcr.io/tetra-fox/nowplaying:latest";
    ports = ["8090:3000"];
    environment.LASTFM_USER = "tetrafox_";
    environmentFiles = siteEnvFile "nowplaying.env";
  };
}
