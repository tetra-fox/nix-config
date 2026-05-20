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
    ./auth.nix
    ./monitoring.nix

    modules.disko.proxmox-vm
    modules.profiles.server.system

    modules.sops.system
    modules.jellyfin.system
    modules.postgres.system
    modules.caddy.system
    modules.samba.system
    modules.docker.system
    modules.nvidia.system
    modules.arr-stack.default
  ];

  lab.arrStack = {
    torrentsPath = "/mnt/vol_1/milkfish/torrents";
    nzbPath = "/mnt/vol_1/milkfish/nzb";
  };

  lab.sops.secretsFile = ../../secrets/mesa-svc-01.yaml;

  lab.postgres = {
    allowedCidrs = ["192.168.20.0/24"]; # trusted VLAN
    openFirewall = true; # 5432
    admin.enable = true;
  };

  networking = {
    hostName = "mesa-svc-01";
    # ens18 = server vlan (LAN-routable, default route)
    # ens19 = proxmox SDN internal (vmbr10) for inter-vm traffic on milkfish
    # SDN's dnsmasq IPAM is buggy on pve 9.1, so everything is pinned statically
    useDHCP = false;
    defaultGateway = "192.168.10.1";
    nameservers = ["192.168.10.53"];

    interfaces.ens18.ipv4.addresses = [
      {
        address = "192.168.10.208";
        prefixLength = 24;
      }
    ];

    interfaces.ens19.ipv4.addresses = [
      {
        address = "10.10.0.10";
        prefixLength = 24;
      }
    ];
  };

  # proxmox guest under milkfish; vNICs bridge to milkfish's vmbr0.10 (server vlan) and vmbr10 (sdn)
  topology.self = {
    parent = "milkfish";
    guestType = "vm";
    interfaces.ens18 = {
      virtual = true;
      physicalConnections = [(config.lib.topology.mkConnection "milkfish" "vmbr0.10")];
    };
    interfaces.ens19 = {
      virtual = true;
      physicalConnections = [(config.lib.topology.mkConnection "milkfish" "vmbr10")];
    };
  };

  lab.caddy.caddyfile = ./files/caddy/Caddyfile;

  # servers are unattended, breakage is fixable
  lab.docker.watchtower.enable = true;
  lab.docker.cadvisor.enable = true;

  # CUDA-in-docker via CDI; containers opt in with `--gpus all` (cli) or deploy.resources.reservations.devices (compose)
  hardware.nvidia-container-toolkit.enable = true;

  lab.nvidia.exporter.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [
      "wheel"
      "docker"
      # admin browses /mnt/vol_1/milkfish often; `media` makes ls/cp/mv work without sudo
      "media"
    ];
  };

  home-manager.users.${username}.imports = [./home.nix];

  # paws off!
  system.stateVersion = "26.05";
}
