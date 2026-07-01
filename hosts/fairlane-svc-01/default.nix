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
    modules.desktop.avahi.system # mDNS so the SMB share shows up in Finder/file managers
  ];

  lab.avahi.publish = true;

  lab.arrStack = {
    # the arr DBs have root/download dirs baked in under /mnt/media, so these must match
    # or every item shows as missing.
    torrentsPath = "/mnt/media/torrents";
    nzbPath = "/mnt/media/nzb";
    # caddy proxies sabnzbd under this hostname; sabnzbd rejects it unless whitelisted
    sabnzbdHostWhitelist = ["sabnzbd.fairlane.tetra.cool"];
  };

  lab.sops.secretsFile = ../../secrets/fairlane-svc-01.yaml;

  lab.postgres = {
    server.enable = true;
    extraAllowedCidrs = ["192.168.20.0/24"];
    openFirewall = true;
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

  lab.podman.autoUpdate.enable = true;

  users.users.${username}.extraGroups = [
    "podman"
    "media"
  ];

  # paws off!
  system.stateVersion = "26.05";
}
