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
    modules.podman.system
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
    # ens18 = server vlan (LAN-routable, default route). single-NIC.
    useDHCP = false;
    defaultGateway = "192.168.10.1";
    nameservers = ["192.168.10.53"];

    interfaces.ens18 = {
      mtu = 9000; # jumbo frames; milkfish bridge + switch are 9000 end-to-end
      ipv4.addresses = [
        {
          address = "192.168.10.208";
          prefixLength = 24;
        }
      ];
    };
  };

  # proxmox guest under milkfish; single vNIC on the server vlan
  topology.self = {
    parent = "milkfish";
    guestType = "vm";
    interfaces.ens18 = {
      virtual = true;
      physicalConnections = [(config.lib.topology.mkConnection "milkfish" "vmbr0.10")];
    };
  };

  lab.caddy.caddyfile = ./files/caddy/Caddyfile;

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
