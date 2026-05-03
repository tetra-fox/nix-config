{
  config,
  lib,
  modules,
  ...
}: let
  cfg = config.lab.nvidia;
in {
  imports = [modules.observability.system];

  options.lab.nvidia.exporter = {
    enable = lib.mkEnableOption "prometheus nvidia-gpu exporter";
    port = lib.mkOption {
      type = lib.types.port;
      default = 9835;
      description = "nvidia_gpu_exporter listen port (upstream default).";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open the exporter port in the firewall. Off by default since the
        local prometheus scrape doesn't need it. Turn this on if a remote
        prometheus on the LAN needs to scrape this host.
      '';
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
      openFirewall = cfg.exporter.openFirewall;
    };

    services.prometheus.scrapeConfigs = lib.mkIf cfg.exporter.enable [
      {
        job_name = "nvidia-${config.networking.hostName}";
        static_configs = [{targets = ["localhost:${toString cfg.exporter.port}"];}];
      }
    ];

    lab.observability.communityDashboards = lib.mkIf cfg.exporter.enable [
      {
        id = 14574;
        revision = 11;
        sha256 = "sha256-0qQ+nVYZ9skOsGhpIFbTtxSkYxe7yRv6WF/56/lbgpw=";
        name = "nvidia-gpu";
      }
    ];
  };
}
