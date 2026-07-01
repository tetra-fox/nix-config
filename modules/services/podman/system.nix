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
  imports = [modules.services.monitoring.registry];

  options.lab.podman = {
    autoUpdate = {
      enable = lib.mkEnableOption "podman-auto-update timer (nightly pull+recreate of containers labelled io.containers.autoupdate=registry)";

      # deriving the container names here instead would recurse on oci-containers.containers
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
      listenAddress = config.lab.monitoring.bindAddr;
    };

    lab.monitoring.exporters = lib.mkIf cfg.cadvisor.enable [
      {
        name = "cadvisor";
        port = cfg.cadvisor.port;
      }
    ];

    services.grafana-dashboards.community = lib.mkIf (cfg.cadvisor.enable && config.lab.monitoring.server.enable) [
      pkgs.grafana-dashboards.cadvisor
    ];

    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
        autoPrune = {
          enable = true;
          dates = "weekly";
        };
      };
      oci-containers.backend = "podman";
    };

    # systemd.packages installs the unit files but not the [Install] section, so enable the timer here
    systemd.timers.podman-auto-update = lib.mkIf cfg.autoUpdate.enable {
      wantedBy = ["timers.target"];
    };

    users.users.${username}.extraGroups = ["podman"];

    # let containers reach native host services over the bridge without exposing those ports to the LAN
    networking.firewall.trustedInterfaces = ["podman0"];
  };
}
