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

  statsFqdn = "stats.${config.lab.site.domain}";

  inherit (cfg) bindAddr;

  # read only input options from other hosts, a derived value makes the cross-host eval cycle
  exportersOf = name: nixosConfigurations.${name}.config.lab.monitoring.exporters or [];
  alertsOf = name: nixosConfigurations.${name}.config.lab.monitoring.alerts or [];
  dashboardsOf = name: nixosConfigurations.${name}.config.lab.monitoring.dashboards or [];

  scrapeAddr = name:
    if name == hn
    then bindAddr
    else ipOf name;

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

  myExporterPorts = map (e: e.port) cfg.exporters;

  localScrapes =
    map (e: {
      job_name = e.name;
      static_configs = [
        {
          targets = ["${bindAddr}:${toString e.port}"];
          labels.instance = hn;
        }
      ];
    })
    cfg.exporters;

  siteAgentIps = lib.filter (ip: ip != null) (map ipOf (lib.filter (name: name != hn) hostsInSite));

  grafanaPort = 3000;
  lokiPort = config.lab.logging.lokiPort;

  # identical registrations collapse, a reused name with a different body trips the assertion.
  # sorted so the provisioned file doesn't depend on host order
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

  # keyed on the name: edits update the rule in place, a rename is a new rule
  alertUid = name: builtins.substring 0 14 (builtins.hashString "sha256" name);

  promDsUid = "prometheus";

  # shared by the server and local grafana
  analyticsOff = {
    reporting_enabled = false;
    check_for_updates = false;
  };

  dashboardPlugins = with pkgs.grafanaPlugins; [
    grafana-clock-panel
    grafana-piechart-panel
  ];

  datasourceSettings = {
    prune = true;
    datasources = [
      {
        name = "prometheus";
        type = "prometheus";
        access = "proxy";
        url = "http://localhost:${toString config.services.prometheus.port}";
        isDefault = true;
        # pinned: the dashboard packages sed DS_PROMETHEUS to this uid
        uid = promDsUid;
      }
    ];
  };

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
          inherit (a) expr;
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
  # blackbox gates itself on server.enable
  imports = [
    modules.services.monitoring.registry
    modules.services.monitoring.blackbox
  ];

  config = lib.mkMerge [
    # agent, every host
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

      lab.monitoring = {
        exporters = [
          {
            name = "node";
            port = nodePort;
          }
          {
            name = "systemd";
            port = systemdPort;
          }
        ];

        dashboards = with pkgs.grafana-dashboards; [
          node-exporter-full
          systemd-exporter
        ];

        alerts = [
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
            # round() here and below so summaries render "85.3%" not a 16-digit float
            expr = ''round(100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|zfs"} / node_filesystem_size_bytes{fstype!~"tmpfs|ramfs|zfs"}), 0.1)'';
            condition.value = 85;
            for = "30m";
            summary = "{{ $labels.mountpoint }} on {{ $labels.instance }} is {{ $values.B }}% full";
            labels.severity = "warning";
          }
          {
            # event alert: the 15m window keeps it visible, a pending period only delays it
            name = "oom kills";
            expr = "round(increase(node_vmstat_oom_kill[15m]))";
            for = "0s";
            summary = "{{ $values.B }} oom kill(s) on {{ $labels.instance }} in the last 15m, check the journal";
            labels.severity = "warning";
          }
          {
            # Restart=always crash loops never reach the failed state, this catches them
            name = "service flapping";
            expr = "round(increase(systemd_service_restart_total[1h]))";
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
      };

      # open this host's exporter ports to this site's server only
      networking.firewall.extraInputRules = lib.mkIf (multiHost && myExporterPorts != []) (
        allowFrom
        (lib.filter (ip: ip != null) (map ipOf (lib.filter (name: name != hn) siteServers)))
        myExporterPorts
      );
    }

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

      sops.secrets = let
        ownedByGrafana = {
          owner = "grafana";
          group = "grafana";
        };
      in {
        "monitoring/grafana_secret_key" = ownedByGrafana;

        # nixpkgs defaults this to "admin", and fairlane keeps the login form (no oauth).
        # grafana only reads it when creating the admin user, grafana-admin-password applies it after
        "monitoring/grafana_admin_password" = ownedByGrafana;

        # env file with TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID, interpolated into the contact point
        "monitoring/telegram_env" = lib.mkIf cfg.telegram.enable {};
      };
      systemd.services.grafana.serviceConfig.EnvironmentFile =
        lib.mkIf cfg.telegram.enable config.sops.secrets."monitoring/telegram_env".path;

      # grafana can't declaratively change an existing admin password, so reset it on every start
      systemd.services.grafana-admin-password = {
        description = "reconcile the grafana admin password from sops";
        after = ["grafana.service"];
        requires = ["grafana.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          User = "grafana";
          Group = "grafana";
          RemainAfterExit = true;
          LoadCredential = "adminpass:${config.sops.secrets."monitoring/grafana_admin_password".path}";
          # bounds the health wait loop
          TimeoutStartSec = 180;
        };
        # /api/health answers only after the db migration the cli needs.
        # password on stdin, argv is readable from /proc/<pid>/cmdline
        script = ''
          until ${pkgs.curl}/bin/curl -sf http://${bindAddr}:${toString grafanaPort}/api/health >/dev/null; do
            sleep 2
          done
          ${config.services.grafana.package}/bin/grafana cli \
            --homepath ${config.services.grafana.dataDir} \
            admin reset-admin-password --password-from-stdin \
            < "$CREDENTIALS_DIRECTORY/adminpass"
        '';
      };

      services = {
        # option from tetra-nurpkgs/modules/grafana-dashboards.nix
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
              # grafana expects the trailing slash
              root_url = "https://${statsFqdn}/";
            };
            analytics = analyticsOff;
            security = {
              secret_key = "$__file{${config.sops.secrets."monitoring/grafana_secret_key".path}}";
              admin_password = "$__file{${config.sops.secrets."monitoring/grafana_admin_password".path}}";
            };

            # basic auth on /api/* is separate from the login form and defaults on, it would
            # expose the local admin on every published vhost
            "auth.basic".enabled = false;
          };

          declarativePlugins = dashboardPlugins;

          provision = {
            enable = true;
            datasources.settings = datasourceSettings;

            alerting = {
              rules.settings = {
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

              # html parse mode, keep < > & out of rule summaries
              templates.settings = {
                apiVersion = 1;
                templates = [
                  {
                    orgId = 1;
                    name = "homelab";
                    template = ''
                      {{ define "homelab.message" -}}
                      {{ if .Alerts.Firing }}🔥 <b>{{ with .CommonLabels.alertname }}{{ . }}{{ else }}alert{{ end }}</b>{{ with .CommonLabels.severity }} [{{ . }}]{{ end }}{{ if gt (len .Alerts.Firing) 1 }} ({{ len .Alerts.Firing }} firing){{ end }}{{ with (index .Alerts.Firing 0).GeneratorURL }} | <a href="{{ . }}">view</a>{{ end }}
                      {{ range .Alerts.Firing }}• {{ .Annotations.summary }}{{ with .SilenceURL }} <a href="{{ . }}">silence</a>{{ end }}
                      {{ end }}{{ end -}}
                      {{ if .Alerts.Resolved }}✅ <b>{{ with .CommonLabels.alertname }}{{ . }}{{ else }}alert{{ end }}</b> resolved{{ if gt (len .Alerts.Resolved) 1 }} ({{ len .Alerts.Resolved }}){{ end }}
                      {{ range .Alerts.Resolved }}• {{ .Annotations.summary }}
                      {{ end }}{{ end -}}
                      {{ end }}
                    '';
                  }
                ];
              };

              # bottoken/chatid resolve from the env file at provisioning time, never in the store
              contactPoints.settings = lib.mkIf cfg.telegram.enable {
                apiVersion = 1;
                contactPoints = [
                  {
                    orgId = 1;
                    name = "telegram";
                    receivers = [
                      {
                        uid = "telegram";
                        type = "telegram";
                        settings = {
                          bottoken = "$TELEGRAM_BOT_TOKEN";
                          chatid = "$TELEGRAM_CHAT_ID";
                          message = ''{{ template "homelab.message" . }}'';
                          parse_mode = "HTML";
                          disable_web_page_preview = true;
                        };
                      }
                    ];
                  }
                ];
              };

              # replaces grafana's default policy tree
              policies.settings = lib.mkIf cfg.telegram.enable {
                apiVersion = 1;
                policies = [
                  {
                    orgId = 1;
                    receiver = "telegram";
                    group_by = ["grafana_folder" "alertname"];
                    group_wait = "30s";
                    group_interval = "5m";
                    repeat_interval = "4h";
                  }
                ];
              };
            };
          };
        };
      };

      # loki for this site's agents only. grafana's allow comes from its route (_route-firewall.nix)
      networking.firewall.extraInputRules = lib.mkIf (siteAgentIps != []) (
        allowFrom siteAgentIps [lokiPort]
      );
    })

    # local: loopback-only resource monitor for interactive hosts
    (lib.mkIf cfg.local.enable {
      assertions = [
        {
          assertion = !cfg.server.enable;
          message = "lab.monitoring: local.enable and server.enable both configure this host's prometheus + grafana; pick one";
        }
      ];

      services = {
        grafana-dashboards.community = cfg.dashboards;

        prometheus = {
          enable = true;
          listenAddress = "127.0.0.1";
          # used as a task manager, a spike shorter than the scrape interval never shows
          globalConfig.scrape_interval = "5s";
          scrapeConfigs = localScrapes ++ cfg.extraScrapeConfigs;
        };

        grafana = {
          enable = true;

          settings = {
            server = {
              http_addr = "127.0.0.1";
              http_port = grafanaPort;
            };
            analytics = analyticsOff;
            # loopback on a single-user machine, no login
            "auth.anonymous" = {
              enabled = true;
              org_role = "Admin";
            };
            auth = {
              disable_login_form = true;
              disable_signout_menu = true;
            };
            # only encrypts stored datasource credentials, and there are none
            security.secret_key = "local-resource-monitor";
            dashboards.default_home_dashboard_path = "${pkgs.grafana-dashboards.node-exporter-full}";
          };

          declarativePlugins = dashboardPlugins;

          provision = {
            enable = true;
            datasources.settings = datasourceSettings;
          };
        };
      };
    })
  ];
}
