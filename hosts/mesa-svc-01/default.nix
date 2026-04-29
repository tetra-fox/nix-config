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

    # proxmox SDN "internal"
    interfaces.ens19 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "10.10.0.10";
          prefixLength = 24;
        }
      ];
    };
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
