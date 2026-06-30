{
  config,
  username,
  modules,
  ...
}: {
  imports = [
    ./storage.nix
    ./monitoring.nix

    modules.platform.proxmox-vm.system
    modules.platform.disko.proxmox-vm
    modules.meta.profiles.server.system

    modules.platform.sops.system
    modules.services.jellyfin.system
    modules.services.postgres.system
    modules.services.caddy.system
    modules.services.samba.system
    modules.services.podman.system
    modules.services.arr-stack.default
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
    server.enable = true; # fairlane runs its own postgres (single-box site)
    extraAllowedCidrs = ["192.168.20.0/24"]; # trusted VLAN
    openFirewall = true; # 5432
    admin.enable = true;
  };

  networking = {
    hostName = "fairlane-svc-01";
    useDHCP = false;
    defaultGateway = "192.168.10.1";
    nameservers = ["192.168.10.1"];

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

  # the admin user + its home config come from the server profile (base.system declares the
  # user, server.system attaches home-manager). only this box's extra groups are added here.
  users.users.${username}.extraGroups = [
    "podman"
    # admin browses the media volume often; `media` makes ls/cp/mv work without sudo
    "media"
  ];

  # paws off!
  system.stateVersion = "26.05";
}
