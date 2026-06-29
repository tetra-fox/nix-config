{
  lib,
  siteData,
  ...
}: {
  imports = [./apikey.nix];

  # pin the uid so it's identical across boxes; the NFS share squashes on uid, not
  # name. upstream services.jellyfin creates the user but auto-allocates the uid.
  users.users.jellyfin.uid = 991;

  services.jellyfin = {
    enable = true;
    group = lib.mkDefault "media";
    openFirewall = true; # 8096/tcp + 7359/udp (auto-discovery)
    dataDir = "${siteData}/jellyfin/data";
    cacheDir = "${siteData}/jellyfin/cache";
    configDir = "${siteData}/jellyfin/config";
    logDir = "${siteData}/jellyfin/log";
  };
}
