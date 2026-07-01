{
  config,
  lib,
  pkgs,
  modules,
  ...
}: let
  cfg = config.lab.nvidia;
in {
  # options-only, so we can register the gpu exporter without the full monitoring stack
  imports = [modules.services.monitoring.registry];

  options.lab.nvidia.exporter = {
    enable = lib.mkEnableOption "prometheus nvidia-gpu exporter";
    port = lib.mkOption {
      type = lib.types.port;
      default = 9835;
      description = "nvidia_gpu_exporter listen port (upstream default).";
    };
  };

  config = {
    hardware = {
      graphics.enable = true;
      nvidia = {
        # recommended true for turing+ by nvidia
        # https://developer.nvidia.com/blog/nvidia-transitions-fully-towards-open-source-gpu-kernel-modules/
        open = lib.mkDefault true;
        modesetting.enable = true;
        # without this, resume from suspend comes back to garbage framebuffers on turing+
        powerManagement.enable = lib.mkDefault true;
        nvidiaSettings = true;
      };
    };

    services.xserver.videoDrivers = ["nvidia"];

    services.prometheus.exporters.nvidia-gpu = lib.mkIf cfg.exporter.enable {
      enable = true;
      port = cfg.exporter.port;
      listenAddress = config.lab.monitoring.bindAddr;
    };

    lab.monitoring.exporters = lib.mkIf cfg.exporter.enable [
      {
        name = "nvidia";
        port = cfg.exporter.port;
      }
    ];

    services.grafana-dashboards.community = lib.mkIf (cfg.exporter.enable && config.lab.monitoring.server.enable) [
      pkgs.grafana-dashboards.nvidia-gpu
    ];
  };
}
