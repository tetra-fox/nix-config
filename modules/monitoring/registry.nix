# options-only contract shared between exporter PRODUCERS (node/systemd in
# monitoring/system.nix, nvidia, cadvisor, ...) and the CONSUMER (the monitoring
# server). declaring it separately means a module that runs an exporter (e.g. nvidia
# on a desktop) can register into `lab.monitoring.exporters` and read
# `lab.monitoring.bindAddr` WITHOUT pulling in the whole monitoring stack -- the host
# just gets inert option declarations, no prometheus/grafana/node-exporter.
#
# monitoring/system.nix imports this and consumes the registry (folding over each
# site host's exporters to build scrape jobs). nvidia/podman import it to register.
{
  config,
  lib,
  modules,
  nixosConfigurations,
  ...
}: let
  # bindAddr derive: loopback while the site is single-host, the site IP once there's
  # a remote server to serve. uses the shared site-topology (same as the server's
  # scrape derive). only ever read by exporter modules when their exporter is enabled,
  # so on a host that runs no exporter (e.g. hara) this default is declared but unread.
  topo = import modules.lib.site-topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };
  inherit (topo) multiHost myIp;
in {
  options.lab.monitoring = {
    server.enable =
      lib.mkEnableOption "the monitoring server (prometheus + grafana). one per site"
      // {default = false;};

    # the address this host's exporters should bind to (read-only, derived): loopback
    # while the site is single-host, the site IP once there's a remote server to serve.
    bindAddr = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default =
        if multiHost && myIp != null
        then myIp
        else "127.0.0.1";
    };

    # exporter registry: every module that runs a prometheus exporter on this host adds
    # a {name, port} entry. the site's monitoring server reads each host's registry and
    # auto-builds the scrape jobs -- agents expose exporters, the server discovers them.
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
