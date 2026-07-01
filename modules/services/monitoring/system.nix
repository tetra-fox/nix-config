{
  config,
  lib,
  pkgs,
  siteData,
  nixosConfigurations,
  modules,
  fleet,
  ...
}: let
  cfg = config.lab.monitoring;
  hn = config.networking.hostName;
  promStateDir = "${lib.removePrefix "/var/lib/" siteData}/prometheus";

  nodePort = 9100;
  systemdPort = 9558;

  topo = import fleet.topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = hn;
  };
  inherit (topo) hostsInSite ipOf siteServers multiHost myIp;

  bindAddr =
    if multiHost && myIp != null
    then myIp
    else "127.0.0.1";

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
  lokiPort = 3100;
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

      # open every registered exporter port to this site's server only (source-scoped, nftables)
      networking.firewall.extraInputRules = lib.mkIf (multiHost && allExporterPorts != []) (
        lib.concatMapStringsSep "\n" (
          name: let
            ip = ipOf name;
          in
            lib.optionalString (ip != null && name != hn)
            "ip saddr ${ip} tcp dport { ${lib.concatMapStringsSep ", " toString allExporterPorts} } accept"
        )
        siteServers
      );
    }

    # ---- server: prometheus + grafana, one per site ----
    (lib.mkIf cfg.server.enable {
      lab.topology.provides = ["monitoring"];

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

      # expose grafana + loki to this site's agents only (remote caddy proxies stats, remote
      # alloy ships logs), source-scoped, never the whole VLAN
      networking.firewall.extraInputRules = lib.mkIf (siteAgentIps != []) (
        lib.concatMapStringsSep "\n" (
          ip: "ip saddr ${ip} tcp dport { ${toString grafanaPort}, ${toString lokiPort} } accept"
        )
        siteAgentIps
      );
    })
  ];
}
