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
  inherit (cfg) bindAddr;

  # read only these sibling INPUT options, never a monitoring-derived value, or the
  # cross-host eval cycles
  exportersOf = name: nixosConfigurations.${name}.config.lab.monitoring.exporters or [];
  alertsOf = name: nixosConfigurations.${name}.config.lab.monitoring.alerts or [];
  dashboardsOf = name: nixosConfigurations.${name}.config.lab.monitoring.dashboards or [];

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

  # this host's own registrations, not a site-wide fold: the firewall should open
  # exactly the ports something here listens on
  myExporterPorts = map (e: e.port) cfg.exporters;

  siteAgentIps = lib.filter (ip: ip != null) (map ipOf (lib.filter (name: name != hn) hostsInSite));

  grafanaPort = 3000;
  # loki's port is the logging module's fact (lab.logging.lokiPort); the firewall rule
  # here must track it, not restate it
  lokiPort = config.lab.logging.lokiPort;

  # identical registrations from multiple hosts collapse; a name registered twice with
  # different bodies survives the unique and is caught by the assertion below.
  # sorted so the provisioned file doesn't depend on host iteration order
  siteAlerts = lib.sort (a: b: a.name < b.name) (lib.unique (lib.concatMap alertsOf hostsInSite));

  dupAlertNames = let
    names = map (a: a.name) siteAlerts;
  in
    lib.unique (lib.filter (n: lib.count (x: x == n) names > 1) names);

  # cross-host copies of one dashboard are distinct attrsets with the same outPath
  # (lib.unique can't compare derivations), so dedupe on the store path
  siteDashboards = lib.foldl' (
    acc: p:
      if lib.any (q: q.outPath == p.outPath) acc
      then acc
      else acc ++ [p]
  ) [] (lib.concatMap dashboardsOf hostsInSite);

  # same uid scheme as the dashboard packages (sha256 prefix of the name), so edits to
  # an existing rule update it in place and a rename is a new rule
  alertUid = name: builtins.substring 0 14 (builtins.hashString "sha256" name);

  promDsUid = "prometheus";

  # the grafana rule shape: A instant promql, B reduce(last), C threshold. the reduce
  # step exists so summaries can template the measured value as {{ $values.B }}
  mkRule = a: {
    uid = alertUid a.name;
    title = a.name;
    condition = "C";
    data = [
      {
        refId = "A";
        relativeTimeRange = {
          from = 600;
          to = 0;
        };
        datasourceUid = promDsUid;
        model = {
          refId = "A";
          expr = a.expr;
          instant = true;
          range = false;
          intervalMs = 1000;
          maxDataPoints = 43200;
        };
      }
      {
        refId = "B";
        datasourceUid = "__expr__";
        model = {
          refId = "B";
          type = "reduce";
          expression = "A";
          reducer = "last";
        };
      }
      {
        refId = "C";
        datasourceUid = "__expr__";
        model = {
          refId = "C";
          type = "threshold";
          expression = "B";
          conditions = [
            {
              evaluator = {
                type = a.condition.op;
                params = [a.condition.value];
              };
              operator.type = "and";
              query.params = ["C"];
              reducer.type = "last";
              type = "query";
            }
          ];
        };
      }
    ];
    inherit (a) for noDataState;
    execErrState = "Error";
    annotations.summary = a.summary;
    inherit (a) labels;
    isPaused = false;
  };
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

      lab.monitoring.dashboards = with pkgs.grafana-dashboards; [
        node-exporter-full
        systemd-exporter
      ];

      # companion alerts for the exporters above. registered by every host identically,
      # so they collapse to one rule each on the server
      lab.monitoring.alerts = [
        {
          name = "scrape target down";
          expr = "up == bool 0";
          summary = "prometheus can't scrape {{ $labels.job }} on {{ $labels.instance }}";
          labels.severity = "critical";
        }
        {
          name = "systemd unit failed";
          expr = ''max by (name, instance) (systemd_unit_state{state="failed"})'';
          summary = "{{ $labels.name }} on {{ $labels.instance }} is failed";
          labels.severity = "warning";
        }
        {
          # zfs excluded: datasets share the pool, the pool capacity alert covers it
          name = "filesystem filling up";
          expr = ''100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|zfs"} / node_filesystem_size_bytes{fstype!~"tmpfs|ramfs|zfs"})'';
          condition.value = 85;
          for = "30m";
          summary = "{{ $labels.mountpoint }} on {{ $labels.instance }} is {{ $values.B }}% full";
          labels.severity = "warning";
        }
        {
          # event alert: the 15m increase window keeps it visible, a pending
          # period would only delay the notification
          name = "oom kills";
          expr = "increase(node_vmstat_oom_kill[15m])";
          for = "0s";
          summary = "{{ $values.B }} oom kill(s) on {{ $labels.instance }} in the last 15m, check the journal";
          labels.severity = "warning";
        }
        {
          # Restart=always crash loops never reach the failed state, this catches them
          name = "service flapping";
          expr = "increase(systemd_service_restart_total[1h])";
          condition.value = 3;
          for = "0s";
          summary = "{{ $labels.name }} on {{ $labels.instance }} restarted {{ $values.B }} times in the last hour";
          labels.severity = "warning";
        }
        {
          # etcd leases, patroni ttls and dnssec signing all assume sane clocks
          name = "clock out of sync";
          expr = "node_timex_sync_status == bool 0";
          for = "15m";
          summary = "clock on {{ $labels.instance }} is not ntp-synced";
          labels.severity = "warning";
        }
      ];

      # open this host's exporter ports to this site's server only
      networking.firewall.extraInputRules = lib.mkIf (multiHost && myExporterPorts != []) (
        allowFrom
        (lib.filter (ip: ip != null) (map ipOf (lib.filter (name: name != hn) siteServers)))
        myExporterPorts
      );
    }

    # ---- server: prometheus + grafana, one per site ----
    (lib.mkIf cfg.server.enable {
      assertions = [
        {
          assertion = dupAlertNames == [];
          message = "lab.monitoring.alerts: rule name(s) registered more than once with differing bodies: ${lib.concatStringsSep ", " dupAlertNames}";
        }
      ];

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
        # every site host's registered dashboards (this host's own included, node/systemd
        # from the agent block above)
        grafana-dashboards.community = siteDashboards;

        prometheus = {
          enable = true;
          stateDir = promStateDir;
          # nothing remote reads prometheus itself, only the same-box grafana datasource
          listenAddress = "127.0.0.1";

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
            # grafana can't change a provisioned datasource's uid in place, it errors
            # "data source not found" and refuses to start. delete-by-name runs before
            # create each start so the record is recreated with the pinned uid below;
            # only its numeric id churns, which nothing keys on.
            # TODO: drop once every site's grafana has started on this generation
            datasources.settings.deleteDatasources = [
              {
                orgId = 1;
                name = "prometheus";
              }
            ];
            datasources.settings.datasources = [
              {
                name = "prometheus";
                type = "prometheus";
                access = "proxy";
                url = "http://localhost:${toString config.services.prometheus.port}";
                isDefault = true;
                # pinned: the dashboard packages sed their DS_PROMETHEUS var to this
                # string as a uid, and the alert rules reference it (promDsUid)
                uid = promDsUid;
              }
            ];

            alerting.rules.settings = {
              apiVersion = 1;
              groups = lib.optional (siteAlerts != []) {
                orgId = 1;
                name = "fleet";
                folder = "fleet";
                interval = "60s";
                rules = map mkRule siteAlerts;
              };
              deleteRules =
                map (n: {
                  orgId = 1;
                  uid = alertUid n;
                })
                cfg.retiredAlerts;
            };
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
