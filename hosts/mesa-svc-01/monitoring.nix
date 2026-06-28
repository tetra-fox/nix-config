{
  modules,
  siteData,
  ...
}: {
  imports = [
    modules.monitoring.system
    modules.logging.system
  ];

  # this host is a monitoring AGENT: it runs the exporters + ships its logs, and the
  # mesa site's server (mesa-mon-01) scrapes/collects from it. no prometheus/grafana
  # here -- that lives on mon-01.

  # source-scoped peer firewall rules (monitoring module) need the nftables backend,
  # so mon-01 can reach this agent's exporters
  networking.nftables.enable = true;

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
