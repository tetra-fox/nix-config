{
  username,
  modules,
  ...
}: {
  imports = [
    ./storage.nix
    ./asf.nix
    ./nowplaying.nix
    ./monitoring.nix

    modules.profiles.server.system

    modules.platform.sops.system
    modules.services.jellyfin.system
    modules.services.podman.system
    modules.hardware.nvidia.system
    modules.services.arr-stack.default
  ];

  hardware.nvidia-container-toolkit.enable = true;

  lab = {
    arrStack = {
      torrentsPath = "/mnt/store/torrents";
      nzbPath = "/mnt/store/nzb";
      # the forwarded port AirVPN assigned to this account
      torrentingPort = 42924;
      # netnsSnatHosts defaults to [dbServerIp], which SNATs the arrs' netns traffic to
      # the remote db so replies route back; no need to set it.
    };

    sops.secretsFile = ../../secrets/mesa-svc-01.yaml;

    # gets svc-01's hostIp into db's pg_hba; the arrs' netns traffic is SNAT'd to this hostIp.
    postgres.client.enable = true;

    site.hostIp = "192.168.10.130";
    site.internalIp = "10.10.0.130";

    podman.autoUpdate.enable = true;
    podman.cadvisor.enable = true;

    nvidia.exporter.enable = true;
  };

  users.users.${username}.extraGroups = [
    "podman"
    "media"
  ];

  # paws off!
  system.stateVersion = "26.05";
}
