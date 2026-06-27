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

  # node + systemd scrape jobs for one host. the scrape ADDRESS must match where that
  # host's exporters actually bind: for myself that's `bindAddr` (loopback when I'm the
  # only host in the site, my site IP once there are remote peers); for a remote peer
  # it's the peer's site IP. the `instance` label is always the hostname so grafana
  # legends read names, not ip:port (uniform labels -- deliberate change from the old
  # localhost:9100 instance).
  scrapeAddr = name:
    if name == hn
    then bindAddr
    else ipOf name;

  scrapeForHost = name: let
    addr = scrapeAddr name;
  in
    lib.optionals (addr != null) [
      {
        job_name = "node-${name}";
        static_configs = [
          {
            targets = ["${addr}:${toString nodePort}"];
            labels.instance = name;
          }
        ];
      }
      {
        job_name = "systemd-${name}";
        static_configs = [
          {
            targets = ["${addr}:${toString systemdPort}"];
            labels.instance = name;
          }
        ];
      }
    ];

  derivedScrapes = lib.concatMap scrapeForHost hostsInSite;
in {
  options.lab.monitoring = {
    server.enable =
      lib.mkEnableOption "the monitoring server (prometheus + grafana). one per site"
      // {default = false;};

    extraScrapeConfigs = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [];
    };
  };

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

      # open the exporter ports to this site's server only (source-scoped, nftables).
      # empty/no-op while single-host (server is self, scraped over loopback).
      networking.firewall.extraInputRules = lib.mkIf multiHost (
        lib.concatMapStringsSep "\n" (
          name: let
            ip = ipOf name;
          in
            lib.optionalString (ip != null && name != hn)
            "ip saddr ${ip} tcp dport { ${toString nodePort}, ${toString systemdPort} } accept"
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
            http_addr = "127.0.0.1";
            http_port = 3000;
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
    })
  ];
}
