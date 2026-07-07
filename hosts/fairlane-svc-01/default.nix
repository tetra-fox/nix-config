# fairlane-svc-01: arrs + jellyfin, NFS client of store-01. was the fairlane monolith; postgres
# moved to db-01, caddy to edge-01/02, samba to store-01, so this is now a pure compute box.
# networking comes from the fairlane site tag; it advertises media/arr/db-client capabilities.
{
  username,
  modules,
  ...
}: {
  imports = [
    ./storage.nix

    modules.profiles.server.system

    modules.platform.sops.system
    modules.services.jellyfin.system
    modules.services.podman.system
    modules.services.arr-stack.default
  ];

  networking.hostName = "fairlane-svc-01";

  lab = {
    site = {
      hostIp = "192.168.10.130";
      internalIp = "10.10.0.130";
      proxmoxParent = "pooltoy";
    };

    arrStack = {
      # the arr DBs have root/download dirs baked in under /mnt/media, so these must match
      # or every item shows as missing.
      torrentsPath = "/mnt/media/torrents";
      nzbPath = "/mnt/media/nzb";
      sabnzbdHostWhitelist = ["sabnzbd.fairlane.tetra.cool"];
    };

    sops.secretsFile = ../../secrets/fairlane-svc-01.yaml;

    # pure client now: the arrs reach db-01 via the derived endpoint + the netns SNAT. this flag
    # gets svc-01's hostIp into db-01's pg_hba.
    postgres.client.enable = true;

    podman.autoUpdate.enable = true;
  };

  users.users.${username}.extraGroups = [
    "podman"
    "media"
  ];

  # paws off!
  system.stateVersion = "26.05";
}
