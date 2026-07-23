# options-only, so a host can run an exporter (register into lab.monitoring.exporters,
# read lab.monitoring.bindAddr) without pulling in the whole prometheus/grafana stack.
{
  config,
  lib,
  modules,
  topo,
  ...
}: let
  inherit (topo) multiHost myIp;
in {
  options.lab.monitoring = {
    server.enable =
      lib.mkEnableOption "the monitoring server (prometheus + grafana). one per site"
      // {default = false;};

    bindAddr = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default =
        if multiHost && myIp != null
        then myIp
        else "127.0.0.1";
    };

    exporters = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "job name prefix, e.g. \"node\", \"nvidia\", \"cadvisor\" (the host is appended)";
          };
          port = lib.mkOption {type = lib.types.port;};
        };
      });
      default = [];
    };

    extraScrapeConfigs = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [];
    };

    dashboards = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "grafana dashboard packages (pkgs.grafana-dashboards.*) this host wants on its site's grafana. the server folds every site host's list into its community provider";
    };

    alerts = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "rule title, unique per site (the grafana uid is derived from it). identical registrations from multiple hosts collapse to one rule";
          };
          expr = lib.mkOption {
            type = lib.types.str;
            description = "instant promql query. one alert instance fires per returned series breaching the condition; use `== bool` comparisons to map a state to 0/1";
          };
          condition = {
            op = lib.mkOption {
              type = lib.types.enum ["gt" "lt"];
              default = "gt";
            };
            value = lib.mkOption {
              type = lib.types.number;
              default = 0;
            };
          };
          for = lib.mkOption {
            type = lib.types.str;
            default = "5m";
            description = "how long the condition must hold before the rule fires";
          };
          summary = lib.mkOption {
            type = lib.types.str;
            description = "summary annotation. go-templated: {{ $labels.x }}, {{ $values.B }} (B is the reduced query value)";
          };
          labels = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {};
            example = {severity = "critical";};
          };
          # OK not NoData: a vanished series usually means the exporter died, which the
          # target-down alert already catches; NoData would fire both
          noDataState = lib.mkOption {
            type = lib.types.enum ["OK" "NoData" "Alerting"];
            default = "OK";
          };
        };
      });
      default = [];
      description = "grafana alert rules this host wants evaluated by its site's grafana. the server folds every site host's list into one provisioned rule group";
    };

    # the bot token + chat id stay out of the repo: the secret is an env file
    # (TELEGRAM_BOT_TOKEN=... / TELEGRAM_CHAT_ID=...) grafana's unit loads, and the
    # provisioned contact point references the vars
    telegram.enable =
      lib.mkEnableOption "declaratively provisioned telegram contact point + notification policy (needs the monitoring/telegram_env sops secret)"
      // {default = false;};

    retiredAlerts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "names of alert rules to delete from grafana. provisioned rules that simply vanish from the config are kept by grafana, so removing a rule means moving its name here (set on the server host)";
    };
  };
}
