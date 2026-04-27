{...}: {
  hardware = {
    graphics.enable = true;
    nvidia = {
      # recommended true for turing+ by nvidia
      # https://developer.nvidia.com/blog/nvidia-transitions-fully-towards-open-source-gpu-kernel-modules/
      open = true;
      modesetting.enable = true;
      # required for clean resume from suspend on turing+ — saves/restores VRAM
      # via nvidia-{suspend,resume}.service, otherwise the display engine
      # comes back to garbage framebuffers and nv_drm_atomic_commit times out
      powerManagement.enable = true;
      nvidiaSettings = true;
    };
  };

  services.xserver.videoDrivers = ["nvidia"];
}
