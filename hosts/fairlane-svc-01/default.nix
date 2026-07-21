# fairlane-svc-01: arrs + jellyfin, NFS client of store-01. was the fairlane monolith; postgres
# moved to db-01, caddy to edge-01/02, samba to store-01, so this is now a pure compute box.
# networking comes from the fairlane site tag; it advertises media/arr/db-client capabilities.
{config, ...}: {
  imports = [
    ../common/arr-host.nix
    ./storage.nix
  ];

  lab = {
    site = {
      hostIp = "192.168.10.130";
      internalIp = "10.10.0.130";
      proxmoxParent = "pooltoy";
    };

    arrStack = {
      # the arr DBs have root/download dirs baked in under /mnt/media, so these must match
      # or every item shows as missing.
      torrentsPath = "/mnt/media/torrents";
      nzbPath = "/mnt/media/nzb";
      # the forwarded port AirVPN assigned to this account (same account as mesa)
      torrentingPort = 42924;
      sabnzbdHostWhitelist = ["sabnzbd.${config.lab.site.domain}"];
    };
  };
}
