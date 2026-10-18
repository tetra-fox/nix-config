{
  config,
  lib,
  pkgs,
  modules,
  ...
}: let
  cfg = config.lab.nvidia;
in {
  # options only, no monitoring stack
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
    # the nixos cuda team's hydra cache, cache.nixos.org skips unfree cuda builds
    # https://wiki.nixos.org/wiki/Cuda
    nix.settings = {
      substituters = ["https://cache.nixos-cuda.org"];
      trusted-public-keys = ["cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="];
    };

    hardware = {
      graphics.enable = true;
      nvidia = {
        # nvidia recommends it for turing+
        # https://developer.nvidia.com/blog/nvidia-transitions-fully-towards-open-source-gpu-kernel-modules/
        open = lib.mkDefault true;
        modesetting.enable = true;
        # without it resume shows garbage framebuffers on turing+
        powerManagement.enable = lib.mkDefault true;
        nvidiaSettings = true;
      };
    };

    services = {
      xserver.videoDrivers = ["nvidia"];

      prometheus.exporters.nvidia-gpu = lib.mkIf cfg.exporter.enable {
        enable = true;
        port = cfg.exporter.port;
        listenAddress = config.lab.monitoring.bindAddr;
        # the dashboard's process panels need these
        extraFlags = ["--collect.compute-apps"];
      };
    };

    lab.monitoring = lib.mkIf cfg.exporter.enable {
      exporters = [
        {
          name = "nvidia";
          port = cfg.exporter.port;
        }
      ];
      dashboards = [pkgs.grafana-dashboards.nvidia-gpu];
      alerts = [
        {
          name = "gpu temperature high";
          expr = "nvidia_smi_temperature_gpu";
          condition.value = 85;
          for = "15m";
          summary = "gpu on {{ $labels.instance }} at {{ $values.B }}C";
          labels.severity = "warning";
        }
      ];
    };
  };
}
