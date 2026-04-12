{ pkgs, username, ... }:

{
  # sudo setcap CAP_SYS_NICE+ep ~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor-launcher
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraProfile = ''
        # Fixes timezones on VRChat
        unset TZ
        # Allows Monado/WiVRn to be used
        export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
      '';
    };
    # currently recommended by the linux vr adventures wiki for vrchat
    # provided by nix-community/nixpkgs-xr nixpkgs overlay
    # https://wiki.vronlinux.org/docs/vrchat/#recommended-proton
    extraCompatPackages = with pkgs; [
      proton-ge-rtsp-bin
    ];
  };

  # use gamemode scheduler
  programs.gamemode.enable = true;

  services.monado = {
    enable = true;
    defaultRuntime = true; # Register as default OpenXR runtime
    highPriority = true;
  };

  users.users.${username}.extraGroups = [
    "video"
    "render"
  ];

  systemd.user.services.monado.environment = {
    STEAMVR_LH_ENABLE = "1";
    XRT_COMPOSITOR_COMPUTE = "1";
    IPC_EXIT_WHEN_IDLE = "1";

    # fixes vkAcquireXlibDisplayEXT: VK_ERROR_UNKNOWN (0x000058b7a0764a80)
    # https://wiki.vronlinux.org/docs/fossvr/monado/#nvidia-specific-vkacquirexlibdisplayext-vk_error_unknown-0x000058b7a0764a80
    XRT_COMPOSITOR_FORCE_WAYLAND_DIRECT = "1";

    # reduce latency when looking around
    # https://wiki.vronlinux.org/docs/fossvr/monado/#nvidia-specific-latency-when-moving-your-head
    XRT_COMPOSITOR_USE_PRESENT_WAIT = "1";
    U_PACING_COMP_TIME_FRACTION_PERCENT = "90";
  };

  environment.systemPackages = with pkgs; [
    lighthouse-steamvr
  ];

}
