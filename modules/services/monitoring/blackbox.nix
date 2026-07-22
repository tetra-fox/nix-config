# black-box probes from the site's monitoring server, testing the chains users actually
# hit rather than per-box health: https through the edge for every route the site
# publishes (derived from the route registry, no hand-kept list), a dns query against
# the resolver endpoint, a tcp connect to the db endpoint. imported by system.nix,
# active wherever the server role is
{
  config,
  lib,
  pkgs,
  modules,
  topo,
  ...
}: let
  cfg = config.lab.monitoring;
  inherit (topo) routesInSite dnsEndpointIp dbEndpointIp;

  blackboxPort = config.services.prometheus.exporters.blackbox.port;

  vhosts = lib.unique (map (r: r.host) routesInSite);

  # a name the resolver must answer; every monitored site publishes its stats vhost
  dnsProbeName = "stats.${config.lab.site.domain}";

  # the standard blackbox indirection: prometheus scrapes the exporter, the real
  # target travels as a query param and becomes the instance label
  probeJob = {
    name,
    module,
    targets,
  }: {
    job_name = name;
    metrics_path = "/probe";
    params.module = [module];
    static_configs = [{inherit targets;}];
    relabel_configs = [
      {
        source_labels = ["__address__"];
        target_label = "__param_target";
      }
      {
        source_labels = ["__param_target"];
        target_label = "instance";
      }
      # the community dashboard (14928) filters its panels and template variable on a
      # `target` label, instance alone leaves its legends as raw series identities
      {
        source_labels = ["__param_target"];
        target_label = "target";
      }
      {
        target_label = "__address__";
        replacement = "127.0.0.1:${toString blackboxPort}";
      }
    ];
  };

  blackboxConfig = (pkgs.formats.yaml {}).generate "blackbox.yml" {
    modules = {
      # no ipv6 wan, force v4 everywhere
      https = {
        prober = "http";
        timeout = "10s";
        http = {
          preferred_ip_protocol = "ip4";
          fail_if_not_ssl = true;
        };
      };
      dns = {
        prober = "dns";
        timeout = "5s";
        dns = {
          preferred_ip_protocol = "ip4";
          query_name = dnsProbeName;
          query_type = "A";
        };
      };
      tcp = {
        prober = "tcp";
        timeout = "5s";
        tcp.preferred_ip_protocol = "ip4";
      };
    };
  };
in {
  # options-only dependency, same seam as every other producer
  imports = [modules.services.monitoring.registry];

  config = lib.mkIf cfg.server.enable {
    services.prometheus.exporters.blackbox = {
      enable = true;
      # only the same-box prometheus talks to it
      listenAddress = "127.0.0.1";
      configFile = blackboxConfig;
    };

    lab.monitoring = {
      extraScrapeConfigs =
        lib.optional (vhosts != []) (probeJob {
          name = "blackbox-https";
          module = "https";
          targets = map (h: "https://${h}") vhosts;
        })
        ++ lib.optional (dnsEndpointIp != null) (probeJob {
          name = "blackbox-dns";
          module = "dns";
          targets = ["${dnsEndpointIp}:53"];
        })
        # 5432 is the postgres wire port, also what the ha haproxy listens on
        ++ lib.optional (dbEndpointIp != null) (probeJob {
          name = "blackbox-tcp";
          module = "tcp";
          targets = ["${dbEndpointIp}:5432"];
        });

      dashboards = [pkgs.grafana-dashboards.prometheus-blackbox-exporter];

      alerts = [
        {
          name = "probe failed";
          expr = "probe_success == bool 0";
          summary = "{{ $labels.job }} probe of {{ $labels.instance }} is failing";
          labels.severity = "critical";
        }
        {
          # acme renews certs 30 days out, so at 14 the renewal has been broken
          # for over two weeks already
          name = "tls certificate expiring";
          expr = "(probe_ssl_earliest_cert_expiry - time()) / 86400";
          condition = {
            op = "lt";
            value = 14;
          };
          summary = "cert for {{ $labels.instance }} expires in {{ $values.B }} days";
          labels.severity = "critical";
        }
      ];
    };
  };
}
