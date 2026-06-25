{
  config,
  username,
  modules,
  ...
}: {
  imports = [
    ./storage.nix
    ./monitoring.nix

    modules.disko.proxmox-vm
    modules.profiles.server.system

    modules.sops.system
    modules.jellyfin.system
    modules.postgres.system
    modules.caddy.system
    modules.samba.system
    modules.podman.system
    modules.arr-stack.default
  ];

  lab.arrStack = {
    # the arr DBs (migrated from the old box) have root folders baked in at
    # /mnt/media/media/{Movies,TV} and download dirs at /mnt/media/torrents/{radarr,sonarr},
    # so these must match or every item shows as missing. the disk already has that layout.
    torrentsPath = "/mnt/media/torrents";
    nzbPath = "/mnt/media/nzb";
    # caddy proxies sabnzbd under this hostname; sabnzbd rejects it unless whitelisted
    sabnzbdHostWhitelist = ["sabnzbd.fairlane.tetra.cool"];
  };

  lab.sops.secretsFile = ../../secrets/fairlane-svc-01.yaml;

  lab.postgres = {
    allowedCidrs = ["192.168.20.0/24"]; # trusted VLAN
    openFirewall = true; # 5432
    admin.enable = true;
  };

  networking = {
    hostName = "fairlane-svc-01";
    useDHCP = false;
    defaultGateway = "192.168.10.1";
    nameservers = ["192.168.10.53"]; # adguard

    interfaces.ens18.ipv4.addresses = [
      {
        address = "192.168.10.249";
        prefixLength = 24;
      }
    ];
  };

  # proxmox guest; single vNIC on the server vlan
  topology.self = {
    parent = "pooltoy";
    guestType = "vm";
    interfaces.ens18 = {
      network = "fairlane-server-vlan";
      virtual = true;
      physicalConnections = [(config.lib.topology.mkConnection "pooltoy" "vmbr0.10")];
    };
  };

  lab.caddy.caddyfile = ./files/caddy/Caddyfile;

  # servers are unattended, breakage is fixable
  lab.podman.autoUpdate.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [
      "wheel"
      "podman"
      # admin browses the media volume often; `media` makes ls/cp/mv work without sudo
      "media"
    ];
  };

  home-manager.users.${username}.imports = [./home.nix];

  # paws off!
  system.stateVersion = "26.05";
}
