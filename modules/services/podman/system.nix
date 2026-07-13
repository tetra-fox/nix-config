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
  # lab.podman options live in options.nix so consumers can import the contract alone
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
