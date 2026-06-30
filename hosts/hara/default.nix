{
  config,
  modules,
  ...
}: {
  imports = [
    modules.profiles.workstation.system

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

    interfaces.enp11s0f0np0.ipv4.addresses = [
      {
        address = "192.168.20.86";
        prefixLength = 24;
      }
    ];
    defaultGateway = "192.168.20.1";
    nameservers = ["192.168.10.1"];
    search = ["mesa.tetra.cool"];
  };

  networking.firewall.allowedUDPPorts = [51820];

  # physical cabling for the topology diagram
  topology.self.interfaces.enp11s0f0np0.physicalConnections = [
    (config.lib.topology.mkConnection "tengigablort" "eth1")
  ];

  # paws off!
  system.stateVersion = "25.11";
}
