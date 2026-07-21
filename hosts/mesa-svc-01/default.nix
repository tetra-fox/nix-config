{modules, ...}: {
  imports = [
    ../common/arr-host.nix
    ./storage.nix
    ./asf.nix
    ./nowplaying.nix

    modules.hardware.nvidia.system
  ];

  hardware.nvidia-container-toolkit.enable = true;

  lab = {
    arrStack = {
      torrentsPath = "/mnt/store/torrents";
      nzbPath = "/mnt/store/nzb";
      # the forwarded port AirVPN assigned to this account
      torrentingPort = 42924;
      # netnsSnatHosts defaults to [dbEndpointIp], which SNATs the arrs' netns traffic to
      # the remote db so replies route back; no need to set it.
    };

    site.hostIp = "192.168.10.130";
    site.internalIp = "10.10.0.130";

    podman.cadvisor.enable = true;

    nvidia.exporter.enable = true;
  };
}
