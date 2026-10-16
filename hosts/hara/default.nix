{
  config,
  modules,
  pkgs,
  username,
  ...
}: {
  imports = [
    modules.profiles.workstation.system

    modules.desktop.greetd.system
    modules.desktop.hyprland.system
    modules.desktop.kde.system
    modules.hardware.nvidia.system
    modules.hardware.ddcci.system
    # modules.hardware.openrgb.system
    modules.desktop.steam.system
    modules.desktop.stylix.system
    modules.services.ollama.system
  ];

  home-manager.users.${username}.imports = [./home];

  lab = {
    # nvidia doesn't hand the DDC/CI bus to ddcci_backlight, so force the attach
    ddcci.forceProbe = true;

    nvidia.exporter.enable = true;

    # steam.lighthouses = ["LHB-460730FA" "LHB-E0CEB24B"];
  };

  services.ollama.package = pkgs.ollama-cuda;

  # TODO: temporary
  hardware.nvidia-container-toolkit.enable = true;

  networking = {
    interfaces.enp11s0f0np0.ipv4.addresses = [
      {
        address = "192.168.20.86";
        prefixLength = 24;
      }
    ];
    defaultGateway = "192.168.20.1";
    # server-VLAN gateway, hara is on the trusted VLAN
    nameservers = [config.lab.net.gateway];
    search = ["mesa.tetra.cool"];
  };

  networking.firewall.allowedUDPPorts = [51820];

  # without the network it renders detached
  topology.self.interfaces.enp11s0f0np0 = {
    network = "mesa-trusted-vlan";
    physicalConnections = [
      (config.lib.topology.mkConnection "tengigablort" "eth1")
    ];
  };

  # paws off!
  system.stateVersion = "25.11";
}
