{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lab.nvidia;
in {
  # the exporter registry options (lab.monitoring.{exporters,bindAddr,server.enable})
  # so we can register the gpu exporter without depending on the full monitoring stack
  # being imported on this host (e.g. hara has the gpu but no monitoring server).
  imports = [../monitoring/registry.nix];

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
        # required for clean resume from suspend on turing+ - saves/restores VRAM
        # via nvidia-{suspend,resume}.service, otherwise the display engine
        # comes back to garbage framebuffers and nv_drm_atomic_commit times out.
        powerManagement.enable = lib.mkDefault true;
        nvidiaSettings = true;
      };
    };

    services.xserver.videoDrivers = ["nvidia"];

    services.prometheus.exporters.nvidia-gpu = lib.mkIf cfg.exporter.enable {
      enable = true;
      port = cfg.exporter.port;
      # bind where the monitoring server expects to scrape (loopback single-host, site
      # IP once there's a remote server); the registry entry below tells it the port.
      listenAddress = config.lab.monitoring.bindAddr;
    };

    # register the exporter so the site's monitoring server auto-discovers + scrapes it
    # (agents expose exporters, the server scrapes them). no manual scrapeConfig.
    lab.monitoring.exporters = lib.mkIf cfg.exporter.enable [
      {
        name = "nvidia";
        port = cfg.exporter.port;
      }
    ];

    # the dashboard only makes sense where grafana runs (the server)
    services.grafana-dashboards.community = lib.mkIf (cfg.exporter.enable && config.lab.monitoring.server.enable) [
      pkgs.grafana-dashboards.nvidia-gpu
    ];
  };
}
