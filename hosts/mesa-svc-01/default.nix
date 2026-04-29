{
  username,
  modules,
  quirks,
  ...
}: {
  imports = [
    quirks
    ./disko.nix
    ./storage.nix
    ./asf.nix
    ./nowplaying.nix
    ./auth.nix
    ./monitoring.nix

    modules.profiles.server.system

    modules.sops.system
    modules.jellyfin.system
    modules.postgres.system
    modules.caddy.system
    modules.samba.system
    modules.docker.system
    modules.netns-vpn.system
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
    # ens18 = server vlan (LAN-routable, default route),
    # ens19 = proxmox SDN "internal" (vmbr10) for inter-vm traffic on
    # milkfish. SDN's dnsmasq IPAM is buggy on pve 9.1 so everything
    # pinned statically here.
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

  # nest under milkfish in nix-topology since this is a proxmox guest.
  topology.self = {
    parent = "milkfish";
    guestType = "vm";
  };

  lab.caddy.caddyfile = ./files/caddy/Caddyfile;

  # nightly image auto-update; servers are unattended, breakage is fixable.
  lab.docker.watchtower.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [
      "wheel"
      "docker"
      # admin browses /mnt/vol_1/milkfish frequently; `media` group makes
      # ls/cp/mv work without sudo. service-specific groups stay closed.
      "media"
    ];
  };

  home-manager.users.${username}.imports = [./home.nix];

  # paws off!
  system.stateVersion = "26.05";
}
