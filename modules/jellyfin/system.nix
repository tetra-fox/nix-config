{
  lib,
  siteData,
  ...
}: {
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
