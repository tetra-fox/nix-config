{
  config,
  username,
  modules,
  ...
}: {
  imports = [
    ./storage.nix
    ./asf.nix
    ./nowplaying.nix
    ./monitoring.nix

    modules.platform.proxmox-vm.system
    modules.platform.disko.proxmox-vm
    modules.meta.profiles.server.system

    modules.platform.sops.system
    modules.services.jellyfin.system
    modules.services.postgres.system
    modules.services.podman.system
    modules.services.nvidia.system
    modules.services.arr-stack.default
  ];

  lab.arrStack = {
    torrentsPath = "/mnt/store/torrents";
    nzbPath = "/mnt/store/nzb";
    # netnsSnatHosts defaults to [dbServerIp], which SNATs the arrs' netns traffic to
    # the remote db so replies route back; no need to set it.
  };

  lab.sops.secretsFile = ../../secrets/mesa-svc-01.yaml;

  # gets svc-01's hostIp into db's pg_hba; the arrs' netns traffic is SNAT'd to this hostIp.
  lab.postgres.client.enable = true;

  networking.hostName = "mesa-svc-01";
  lab.site.hostIp = "192.168.10.130";
  lab.site.internalIp = "10.10.0.130";

  lab.podman.autoUpdate.enable = true;
  lab.podman.cadvisor.enable = true;

  hardware.nvidia-container-toolkit.enable = true;

  lab.nvidia.exporter.enable = true;

  users.users.${username}.extraGroups = [
    "podman"
    "media"
  ];

  # paws off!
  system.stateVersion = "26.05";
}
