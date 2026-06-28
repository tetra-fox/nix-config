# monitoring, split into two roles:
#   agent  (always on, every host): node-exporter + systemd-exporter. produces
#          metrics about this host. unconditional -- there's no host we'd want
#          unobserved, so self-observability is an invariant, not a toggle.
#   server (lab.monitoring.server.enable): prometheus + grafana on top. one per
#          site (the <site>-mon-01 box). scrapes every agent in its site.
#
# a "site" is the hostname prefix: mesa-svc-01, mesa-svc-02, mesa-mon-01 all share
# site `mesa`. the server auto-derives its scrape list by folding over the other
# hosts in the flake that share its site prefix and reading their declared static
# IPs -- no hand-maintained target list, no DNS dependency.
#
# today each site has exactly one host and it's the server, so the derived peer set
# is just [self] and everything binds loopback. the remote-agent machinery (off-loopback
# binds, source-scoped firewall rules) stays dormant until a site gains a second host.
{
  config,
  lib,
  pkgs,
  siteData,
  nixosConfigurations,
  modules,
  ...
}: let
  cfg = config.lab.monitoring;
  hn = config.networking.hostName;
  promStateDir = "${lib.removePrefix "/var/lib/" siteData}/prometheus";

  nodePort = 9100;
  systemdPort = 9558;

  # shared site-topology derivation (see site-topology.nix; same logic the logging
  # module uses to find this host's site peers + server).
  topo = import ./site-topology.nix {inherit lib;} {
    inherit nixosConfigurations;
    hostName = hn;
  };
  inherit (topo) hostsInSite ipOf siteServers multiHost myIp;

  # bind to the site IP only when there's a remote peer to serve; else loopback.
  bindAddr =
    if multiHost && myIp != null
    then myIp
    else "127.0.0.1";

  # the exporters a given site host runs, read from its registry. every exporter
  # (node, systemd, nvidia, cadvisor, ...) registers a {name, port} here, so the
  # server discovers them uniformly. reads only this sibling INPUT option -- never a
  # monitoring-derived value -- so no cross-host eval cycle.
  exportersOf = name: nixosConfigurations.${name}.config.lab.monitoring.exporters or [];

  # the scrape ADDRESS for a host must match where its exporters actually bind: for
  # myself that's `bindAddr` (loopback when I'm the only host in the site, my site IP
  # once there are remote peers); for a remote peer it's the peer's site IP.
  scrapeAddr = name:
    if name == hn
    then bindAddr
    else ipOf name;

  # one scrape job per exporter on one host. job name is "<exporter>-<host>" and the
  # `instance` label is always the hostname so grafana legends read names, not ip:port.
  scrapeForHost = name: let
    addr = scrapeAddr name;
  in
    lib.optionals (addr != null) (
      map (e: {
        job_name = "${e.name}-${name}";
        static_configs = [
          {
            targets = ["${addr}:${toString e.port}"];
            labels.instance = name;
          }
        ];
      })
      (exportersOf name)
    );

  derivedScrapes = lib.concatMap scrapeForHost hostsInSite;

  # union of all exporter ports across this site's agents, to open to the server.
  allExporterPorts = lib.unique (lib.concatMap (name: map (e: e.port) (exportersOf name)) hostsInSite);

  # the site's agents (every host in the site that isn't me/the server). the server
  # exposes grafana + loki to these so a remote caddy can reach grafana and remote
  # alloy can ship logs to loki. their IPs feed the server-side firewall allow rules.
  siteAgentIps = lib.filter (ip: ip != null) (map ipOf (lib.filter (name: name != hn) hostsInSite));

  grafanaPort = 3000;
  lokiPort = 3100;
in {
  # lab.monitoring.{server.enable, bindAddr, exporters, extraScrapeConfigs} are declared
  # in the options-only registry module, so exporter producers can register without
  # pulling in this whole stack.
  imports = [modules.monitoring.registry];

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

      # node + systemd register into the exporter registry like any other exporter, so
      # the server discovers them the same uniform way (no special-casing).
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

      # open every registered exporter port to this site's server only (source-scoped,
      # nftables). empty/no-op while single-host (server is self, scraped over loopback).
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
      sops.secrets."monitoring/grafana_secret_key" = {
        owner = "grafana";
        group = "grafana";
      };

      services.grafana-dashboards.community = with pkgs.grafana-dashboards; [
        node-exporter-full
        systemd-exporter
      ];

      services.prometheus = {
        enable = true;
        stateDir = promStateDir;

        globalConfig = {
          scrape_interval = "15s";
          evaluation_interval = "15s";
        };

        scrapeConfigs = derivedScrapes ++ cfg.extraScrapeConfigs;
      };

      services.grafana = {
        enable = true;
        dataDir = "${siteData}/grafana";

        settings = {
          server = {
            # bind the site IP once there's a remote host that needs to reach grafana
            # (e.g. caddy on a svc box proxying stats.<site>); loopback while single-host.
            http_addr = bindAddr;
            http_port = grafanaPort;
          };
          analytics = {
            reporting_enabled = false;
            check_for_updates = false;
          };
          # grafana 26.05+ needs an explicit secret_key (cookie signing)
          security.secret_key = "$__file{${config.sops.secrets."monitoring/grafana_secret_key".path}}";
        };

        declarativePlugins = with pkgs.grafanaPlugins; [
          grafana-clock-panel
          grafana-piechart-panel
        ];

        # provider wiring lives in tetra-nurpkgs/modules/grafana-dashboards.nix;
        # it reads services.grafana-dashboards.{community,extras} and writes the providers list
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

      # expose grafana (for a remote caddy proxying stats.<site>) and loki (for remote
      # alloy shipping logs) to this site's agents only -- source-scoped, never the whole
      # VLAN. empty/no-op while single-host. loki itself binds the site IP via the logging
      # module's bindAddr; grafana binds it above.
      networking.firewall.extraInputRules = lib.mkIf (siteAgentIps != []) (
        lib.concatMapStringsSep "\n" (
          ip: "ip saddr ${ip} tcp dport { ${toString grafanaPort}, ${toString lokiPort} } accept"
        )
        siteAgentIps
      );
    })
  ];
}
