{
  modules,
  siteData,
  ...
}: {
  imports = [
    modules.services.monitoring.system
    modules.services.logging.system
  ];

  lab.logging = {
    # journald + the arr file logs -> shipped to mon-01's loki
    enable = true;

    # the *arr apps log more detail to their <name>.txt than to stdout. tail the
    # current (non-rotated) file; sabnzbd/qbittorrent logs are 0600 owner-only so
    # they stay journal-only. media group grants read on these 0644/0664 files
    extraGroups = ["media"];
    fileSources = [
      {
        job = "sonarr";
        path = "${siteData}/sonarr/logs/sonarr.txt";
      }
      {
        job = "radarr";
        path = "${siteData}/radarr/logs/radarr.txt";
      }
      {
        job = "prowlarr";
        path = "${siteData}/prowlarr/logs/prowlarr.txt";
      }
    ];
  };
}
