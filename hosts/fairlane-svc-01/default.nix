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
      # baked into the arr DBs, changing these marks every item missing
      torrentsPath = "/mnt/media/torrents";
      nzbPath = "/mnt/media/nzb";
      # AirVPN's forwarded port, same account as mesa
      torrentingPort = 42924;
      sabnzbdHostWhitelist = ["sabnzbd.${config.lab.site.domain}"];
    };
  };
}
