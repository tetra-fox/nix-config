{
  config,
  lib,
  pkgs,
  nixosConfigurations,
  modules,
  fleet,
  topo,
  caps,
  ...
}: let
  siteData = config.lab.site.dataDir;
  cfg = config.lab.monitoring;
  allowFrom = import fleet.nft {inherit lib;};
  hn = config.networking.hostName;
  promStateDir = "${lib.removePrefix "/var/lib/" siteData}/prometheus";

  nodePort = 9100;
  systemdPort = 9558;

  inherit (topo) hostsInSite ipOf siteServers multiHost;

  # grafana's public fqdn. declared once here and used for BOTH the stats route and grafana's
  # root_url below, so the hostname isn't restated. reads only lab.site.domain (a plain input),
  # never a topo derive, so it can't cycle.
  statsFqdn = "stats.${config.lab.site.domain}";

  # the registry (registry.nix) owns the bind-address rule; read it, don't recompute it
  bindAddr = cfg.bindAddr;

  # read only this sibling INPUT option, never a monitoring-derived value, or the
  # cross-host eval cycles
  exportersOf = name: nixosConfigurations.${name}.config.lab.monitoring.exporters or [];

  scrapeAddr = name:
    if name == hn
    then bindAddr
    else ipOf name;

  # one scrape job per exporter TYPE (node, systemd, ...), not per host: the prometheus-native
  # shape where a job is a class of target and the hosts are its members
  scrapeTuples =
    lib.concatMap (
      name: let
        addr = scrapeAddr name;
      in
        lib.optionals (addr != null) (map (e: {
          inherit (e) name port;
          host = name;
          inherit addr;
        }) (exportersOf name))
    )
    hostsInSite;

  byExporter = lib.groupBy (t: t.name) scrapeTuples;

  derivedScrapes =
    lib.mapAttrsToList (exporterName: members: {
      job_name = exporterName;
      static_configs =
        map (t: {
          targets = ["${t.addr}:${toString t.port}"];
          labels.instance = t.host;
        })
        members;
    })
    byExporter;

  allExporterPorts = lib.unique (lib.concatMap (name: map (e: e.port) (exportersOf name)) hostsInSite);

  siteAgentIps = lib.filter (ip: ip != null) (map ipOf (lib.filter (name: name != hn) hostsInSite));

  grafanaPort = 3000;
  # loki's port is the logging module's fact (lab.logging.lokiPort); the firewall rule
  # here must track it, not restate it
  lokiPort = config.lab.logging.lokiPort;
in {
  # options-only, so an exporter producer can register without pulling in this whole stack
  imports = [modules.services.monitoring.registry];

  config = lib.mkMerge [
    # ---- agent: always on, every host ----
    {
      # without this the systemd_unit_ip_{egress,ingress}_bytes series are all zero
      systemd.settings.Manager.DefaultIPAccounting = true;

      services.prometheus.exporters.node = {
        enable = true;
        listenAddress = bindAddr;
        enabledCollectors = ["systemd" "processes"];
      };

      services.prometheus.exporters.systemd = {
        enable = true;
        listenAddress = bindAddr;
        extraFlags = [
          "--systemd.collector.enable-restart-count"
          "--systemd.collector.enable-ip-accounting"
        ];
      };

      lab.monitoring.exporters = [
        {
          name = "node";
          port = nodePort;
        }
        {
          name = "systemd";
          port = systemdPort;
        }
      ];

      # open every registered exporter port to this site's server only
      networking.firewall.extraInputRules = lib.mkIf (multiHost && allExporterPorts != []) (
        allowFrom
        (lib.filter (ip: ip != null) (map ipOf (lib.filter (name: name != hn) siteServers)))
        allExporterPorts
      );
    }

    # ---- server: prometheus + grafana, one per site ----
    (lib.mkIf cfg.server.enable {
      lab.topology.provides = [caps.monitoring.name];
      lab.topology.routes = [
        {
          host = statsFqdn;
          port = grafanaPort;
        }
      ];

      sops.secrets."monitoring/grafana_secret_key" = {
        owner = "grafana";
        group = "grafana";
      };

      services = {
        grafana-dashboards.community = with pkgs.grafana-dashboards; [
          node-exporter-full
          systemd-exporter
        ];

        prometheus = {
          enable = true;
          stateDir = promStateDir;

          globalConfig = {
            scrape_interval = "15s";
            evaluation_interval = "15s";
          };

          scrapeConfigs = derivedScrapes ++ cfg.extraScrapeConfigs;
        };

        grafana = {
          enable = true;
          dataDir = "${siteData}/grafana";

          settings = {
            server = {
              http_addr = bindAddr;
              http_port = grafanaPort;
              # public url grafana generates links/redirects against, from the same statsFqdn the
              # route uses. trailing slash is what grafana expects.
              root_url = "https://${statsFqdn}/";
            };
            analytics = {
              reporting_enabled = false;
              check_for_updates = false;
            };
            security.secret_key = "$__file{${config.sops.secrets."monitoring/grafana_secret_key".path}}";
          };

          declarativePlugins = with pkgs.grafanaPlugins; [
            grafana-clock-panel
            grafana-piechart-panel
          ];

          # provider wiring: tetra-nurpkgs/modules/grafana-dashboards.nix reads
          # services.grafana-dashboards.{community,extras}
          provision = {
            enable = true;
            datasources.settings.prune = true;
            datasources.settings.datasources = [
              {
                name = "prometheus";
                type = "prometheus";
                access = "proxy";
                url = "http://localhost:${toString config.services.prometheus.port}";
                isDefault = true;
              }
            ];
          };
        };
      };

      # expose loki to this site's agents only (remote alloy ships logs), never the whole
      # VLAN. grafana's allow is derived from its route (_route-firewall.nix): only the
      # edge hosts proxy it, agents have no business on 3000.
      networking.firewall.extraInputRules = lib.mkIf (siteAgentIps != []) (
        allowFrom siteAgentIps [lokiPort]
      );
    })
  ];
}
