{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.lab.podman;
in {
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
    };

    services.prometheus.scrapeConfigs = lib.mkIf cfg.cadvisor.enable [
      {
        job_name = "cadvisor-${config.networking.hostName}";
        static_configs = [{targets = ["localhost:${toString cfg.cadvisor.port}"];}];
      }
    ];

    services.grafana-dashboards.community = lib.mkIf cfg.cadvisor.enable [
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
