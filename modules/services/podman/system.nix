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
  imports = [
    modules.services.podman.options
    modules.services.monitoring.registry
  ];

  config = {
    services.cadvisor = lib.mkIf cfg.cadvisor.enable {
      enable = true;
      port = cfg.cadvisor.port;
      listenAddress = config.lab.monitoring.bindAddr;
    };

    lab.monitoring = lib.mkIf cfg.cadvisor.enable {
      exporters = [
        {
          name = "cadvisor";
          port = cfg.cadvisor.port;
        }
      ];
      # follows cadvisor to whichever grafana covers this host
      dashboards = [pkgs.grafana-dashboards.cadvisor];
    };

    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
        autoPrune = {
          enable = true;
          # UTC, see SCHEDULE.md
          dates = "Mon 13:00";
          # without --all, images podman-auto-update replaced are never pruned
          flags = ["--all"];
        };
      };
      oci-containers.backend = "podman";
    };

    # systemd.packages skips the [Install] section
    systemd.timers.podman-auto-update = lib.mkIf cfg.autoUpdate.enable {
      wantedBy = ["timers.target"];
      # upstream's midnight UTC restarts containers mid-evening. "" clears the inherited value.
      # see SCHEDULE.md
      timerConfig.OnCalendar = ["" "12:00"];
    };

    users.users.${username}.extraGroups = ["podman"];

    # containers reach native host services without those ports opening to the LAN
    networking.firewall.trustedInterfaces = ["podman0"];
  };
}
