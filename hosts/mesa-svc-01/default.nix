{
  imports = [
    ../common/arr-host.nix
    ./storage.nix
    ./asf.nix
    ./bambuddy.nix
    ./nowplaying.nix
    ./radio.nix
  ];

  lab = {
    arrStack = {
      torrentsPath = "/mnt/store/torrents";
      nzbPath = "/mnt/store/nzb";
      # AirVPN's forwarded port
      torrentingPort = 42924;
      slskd = {
        enable = true;
        # AirVPN's forwarded port
        soulseekPort = 22026;
      };
    };

    site.hostIp = "192.168.10.130";
    site.internalIp = "10.10.0.130";

    podman.cadvisor.enable = true;
  };
}
