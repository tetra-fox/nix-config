{
  config,
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

  networking = {
    hostName = "hara";

    # 10G NIC pinned to the workstation vlan; the UDM Pro SE's DHCP
    # reservation matches but pin in nix so it survives any router reset.
    interfaces.enp11s0f0np0.ipv4.addresses = [
      {
        address = "192.168.20.86";
        prefixLength = 24;
      }
    ];
    defaultGateway = "192.168.20.1";
    nameservers = ["192.168.10.53"];
  };

  # nix-topology: declare physical cabling so the diagram draws the link.
  topology.self.interfaces.enp11s0f0np0.physicalConnections = [
    (config.lib.topology.mkConnection "tengigablort" "eth1")
  ];

  # paws off!
  system.stateVersion = "25.11";
}
