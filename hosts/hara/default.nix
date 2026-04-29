{
  modules,
  quirks,
  ...
}: {
  imports = [
    quirks
    modules.profiles.workstation.system

    # hara-specific (DE, GPU, bootloader, gaming-flavor)
    modules.cosmic.system
    modules.greetd.system
    modules.hyprland.system
    modules.nvidia.system
    # modules.openrgb.system
    modules.steam.system
    modules.stylix.system
  ];

  networking.hostName = "hara";

  # paws off!
  system.stateVersion = "25.11";
}
