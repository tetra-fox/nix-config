{
  config,
  lib,
  pkgs,
  username,
  modules,
  ...
}: let
  cfg = config.lab.podman;
in {
  # the exporter registry options so cadvisor can register without depending on the
  # full monitoring stack being imported on this host.
  imports = [modules.services.monitoring.registry];

  options.lab.podman = {
    autoUpdate = {
      enable = lib.mkEnableOption "podman-auto-update timer (nightly pull+recreate of containers labelled io.containers.autoupdate=registry)";

      # read-only: container modules spread this into their `labels` to opt in.
      # keeps the label string and the on/off gating in one place; deriving the
      # names here instead would recurse on oci-containers.containers
      containerLabels = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        readOnly = true;
        default = lib.optionalAttrs cfg.autoUpdate.enable {
          "io.containers.autoupdate" = "registry";
        };
      };
    };

    cadvisor = {
      enable = lib.mkEnableOption "cadvisor container metrics";
      port = lib.mkOption {
        type = lib.types.port;
        default = 8081; # 8080 collides with sabnzbd
      };
    };
  };

  config = {
    services.cadvisor = lib.mkIf cfg.cadvisor.enable {
      enable = true;
      port = cfg.cadvisor.port;
      # bind where the monitoring server expects to scrape (loopback single-host, site
      # IP once there's a remote server); the registry entry below tells it the port.
      listenAddress = config.lab.monitoring.bindAddr;
    };

    # register the exporter so the site's monitoring server auto-discovers + scrapes it
    lab.monitoring.exporters = lib.mkIf cfg.cadvisor.enable [
      {
        name = "cadvisor";
        port = cfg.cadvisor.port;
      }
    ];

    # the dashboard only makes sense where grafana runs (the server)
    services.grafana-dashboards.community = lib.mkIf (cfg.cadvisor.enable && config.lab.monitoring.server.enable) [
      pkgs.grafana-dashboards.cadvisor
    ];

    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = true; # `docker` cli maps to podman
        dockerSocket.enable = true; # docker-API socket for tooling (cadvisor, scripts)
        autoPrune = {
          enable = true;
          dates = "weekly";
        };
      };
      oci-containers.backend = "podman";
    };

    # podman ships podman-auto-update.{service,timer}; systemd.packages installs
    # the files but does not symlink the [Install] section, so enable it here
    systemd.timers.podman-auto-update = lib.mkIf cfg.autoUpdate.enable {
      wantedBy = ["timers.target"];
    };

    users.users.${username}.extraGroups = ["podman"];

    # containers reach native host services (e.g. postgres) over the default
    # bridge without those ports being exposed to the LAN. pg_hba + app auth
    # still apply
    networking.firewall.trustedInterfaces = ["podman0"];
  };
}
