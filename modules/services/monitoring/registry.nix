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
  };
}
