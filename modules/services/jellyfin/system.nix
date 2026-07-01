{
  lib,
  siteData,
  ...
}: {
  imports = [./apikey.nix];

  # pin the uid; the NFS share squashes on uid, not name, and upstream auto-allocates it
  users.users.jellyfin.uid = 991;

  services.jellyfin = {
    enable = true;
    group = lib.mkDefault "media";
    openFirewall = true;
    dataDir = "${siteData}/jellyfin/data";
    cacheDir = "${siteData}/jellyfin/cache";
    configDir = "${siteData}/jellyfin/config";
    logDir = "${siteData}/jellyfin/log";
  };
}
