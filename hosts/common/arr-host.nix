{
  config,
  username,
  modules,
  ...
}: {
  imports = [
    modules.profiles.server.system

    modules.services.jellyfin.system
    modules.services.store-mount.system
    modules.services.podman.system
    modules.services.arr-stack.default
  ];

  lab = {
    storage.mounts.media.gatedServices = [
      "sonarr"
      "radarr"
      "jellyfin"
      "qbittorrent"
      "sabnzbd"
    ];

    # the arrs' netns traffic is SNAT'd to hostIp, which this puts in the db's pg_hba
    postgres.client.enable = true;

    podman.autoUpdate.enable = true;
  };

  users.users.${username}.extraGroups = [
    "podman"
    config.lab.media.group
  ];

  # paws off!
  system.stateVersion = "26.05";
}
