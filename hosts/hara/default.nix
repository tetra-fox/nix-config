{
  config,
  modules,
  pkgs,
  ...
}: {
  imports = [
    modules.profiles.workstation.system

    modules.desktop.cosmic.system
    modules.desktop.greetd.system
    modules.desktop.hyprland.system
    modules.hardware.nvidia.system
    modules.hardware.ddcci.system
    # modules.hardware.openrgb.system
    modules.desktop.steam.system
    modules.desktop.stylix.system

    modules.services.ollama.system
  ];

  # nvidia doesn't hand the DDC/CI bus to ddcci_backlight, so force the attach
  lab.ddcci.forceProbe = true;

  # cuda build for the rtx 3090; the ollama module leaves package at the cpu default
  services.ollama.package = pkgs.ollama-cuda;

  # this room's valve basestations, powered with monado by the steam module
  lab.steam.lighthouses = ["LHB-460730FA" "LHB-E0CEB24B"];

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
