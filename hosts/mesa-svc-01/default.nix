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
    # netnsSnatHosts defaults to [dbServerIp] (db is remote) -- the arrs' netns traffic to
    # db-01 over the internal VLAN gets SNAT'd so replies route back. no need to set it.
  };

  lab.sops.secretsFile = ../../secrets/mesa-svc-01.yaml;

  # postgres moved to mesa-db-01 (Phase 3). svc-01 is now a pure client: the arrs reach
  # db-01 via the auto-derived postgresHost (dbServerIp -> db-01) + the netns SNAT below.
  # client.enable gets svc-01's hostIp into db-01's pg_hba allow-list (the arrs' netns
  # traffic is SNAT'd to this same hostIp). data was migrated; the old local data dir
  # under siteData stays on disk untouched as a rollback point.
  lab.postgres.client.enable = true;

  # site facts (server-VLAN networking, gateway/DNS, siteData root, topology parent)
  # come from the `mesa` tag (modules/sites/mesa.nix). this host declares its own IP.
  networking.hostName = "mesa-svc-01";
  lab.site.hostIp = "192.168.10.130";
  lab.site.internalIp = "10.10.0.130"; # isolated internal VLAN (ens19)

  # servers are unattended, breakage is fixable
  lab.podman.autoUpdate.enable = true;
  lab.podman.cadvisor.enable = true;

  # CUDA-in-podman via CDI; containers opt in with `--device nvidia.com/gpu=all` (cli) or deploy.resources.reservations.devices (compose)
  hardware.nvidia-container-toolkit.enable = true;

  lab.nvidia.exporter.enable = true;

  # the admin user + its home config come from the server profile (base.system declares the
  # user, server.system attaches the home-manager shell config). only the extra groups this
  # box needs are added here -- they merge with the profile's ["wheel"].
  users.users.${username}.extraGroups = [
    "podman"
    # admin browses /mnt/store often; `media` makes ls/cp/mv work without sudo
    "media"
  ];

  # paws off!
  system.stateVersion = "26.05";
}
