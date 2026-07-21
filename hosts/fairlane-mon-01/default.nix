{
  config,
  modules,
  ...
}: {
  imports = [
    ./monitoring.nix

    modules.profiles.server.system
  ];

  lab = {
    site = {
      hostIp = "192.168.10.140";
      internalIp = "10.10.0.140";
      proxmoxParent = "pooltoy";
    };
  };

  # no storage.nix here, so create the siteData root itself
  systemd.tmpfiles.rules = ["d ${config.lab.site.dataDir} 0755 root root -"];

  system.stateVersion = "26.11";
}
