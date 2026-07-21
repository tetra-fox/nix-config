# host-role boilerplate shared by the arr/jellyfin compute boxes (mesa-svc-01,
# fairlane-svc-01): media services + podman, NFS client of the site store, postgres
# client of the site db. per-host facts (paths, IPs) and one-offs (asf, nowplaying,
# nvidia) stay in the host files.
{
  config,
  username,
  modules,
  ...
}: {
  imports = [
    modules.profiles.server.system

    modules.services.jellyfin.system
    modules.services.podman.system
    modules.services.arr-stack.default
  ];

  lab = {
    # gets this host's hostIp into the db's pg_hba; the arrs' netns traffic is SNAT'd to it
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
