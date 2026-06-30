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

    modules.proxmox-vm.system
    modules.disko.proxmox-vm
    modules.profiles.server.system

    modules.sops.system
    modules.jellyfin.system
    modules.postgres.system
    modules.podman.system
    modules.nvidia.system
    modules.arr-stack.default
  ];

  lab.arrStack = {
    torrentsPath = "/mnt/vol_1/milkfish/torrents";
    nzbPath = "/mnt/vol_1/milkfish/nzb";
    # the arrs run in the wg netns; db-01 is off-tunnel (accessibleFrom covers the LAN)
    # but needs host-side SNAT so its replies route back. activates the Phase 0b scaffold.
    netnsSnatHosts = ["192.168.10.245"];
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
  lab.site.hostIp = "192.168.10.208";
  lab.site.internalIp = "10.10.0.208"; # isolated internal VLAN (ens19)

  # extra topology detail beyond the site default's parent
  topology.self = {
    guestType = "vm";
    interfaces.ens18 = {
      virtual = true;
      physicalConnections = [(config.lib.topology.mkConnection "milkfish" "vmbr0.10")];
    };
  };

  # servers are unattended, breakage is fixable
  lab.podman.autoUpdate.enable = true;
  lab.podman.cadvisor.enable = true;

  # CUDA-in-podman via CDI; containers opt in with `--device nvidia.com/gpu=all` (cli) or deploy.resources.reservations.devices (compose)
  hardware.nvidia-container-toolkit.enable = true;

  lab.nvidia.exporter.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [
      "wheel"
      "podman"
      # admin browses /mnt/vol_1/milkfish often; `media` makes ls/cp/mv work without sudo
      "media"
    ];
  };

  home-manager.users.${username}.imports = [./home.nix];

  # paws off!
  system.stateVersion = "26.05";
}
