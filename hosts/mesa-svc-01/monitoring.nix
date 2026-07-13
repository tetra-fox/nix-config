{
  config,
  modules,
  ...
}: {
  imports = [
    modules.services.monitoring.system
    modules.services.logging.system
  ];

  lab.logging = {
    enable = true;

    # the arr apps log more to their <name>.txt than to stdout; media group grants read on
    # those 0644/0664 files. sabnzbd/qbittorrent logs are 0600 so they stay journal-only.
    extraGroups = ["media"];
    fileSources = [
      {
        job = "sonarr";
        path = "${config.lab.site.dataDir}/sonarr/logs/sonarr.txt";
      }
      {
        job = "radarr";
        path = "${config.lab.site.dataDir}/radarr/logs/radarr.txt";
      }
      {
        job = "prowlarr";
        path = "${config.lab.site.dataDir}/prowlarr/logs/prowlarr.txt";
      }
    ];
  };
}
