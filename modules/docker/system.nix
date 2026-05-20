{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.lab.docker;
in {
  options.lab.docker = {
    watchtower.enable = lib.mkEnableOption "watchtower";

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
      docker = {
        enable = true;
        storageDriver = "overlay2";
        logDriver = "json-file";
        daemon.settings.log-opts = {
          "max-size" = "10m";
          "max-file" = "3";
        };
        autoPrune = {
          enable = true;
          dates = "weekly";
        };
      };
      oci-containers = {
        backend = "docker";

        containers = lib.mkIf cfg.watchtower.enable {
          watchtower = {
            image = "ghcr.io/nicholas-fedor/watchtower";
            volumes = ["/var/run/docker.sock:/var/run/docker.sock"];
            cmd = ["--cleanup" "-s" "0 0 11 * * *"]; # 11am local (UTC for servers)
            environment.TZ = config.time.timeZone;
          };
        };
      };
    };

    users.users.${username}.extraGroups = ["docker"];

    networking.firewall = {
      trustedInterfaces = ["docker0"];
      extraInputRules = ''
        iifname "br-*" accept
      '';
    };
  };
}
