{
  config,
  modules,
  pkgs,
  inputs,
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

  # native wine ableton live; consumed via legacyPackages (not the fleet overlay)
  # so it builds against nurpkgs' own nixpkgs pin, see the tetra-nurpkgs input
  # comment in flake.nix. pulls in ableton-wine.
  environment.systemPackages = [
    inputs.tetra-nurpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.ableton-live
  ];

  # the launcher's realtime probe (`chrt -r 10`) needs RLIMIT_RTPRIO, which rtkit
  # alone doesn't grant; scoped to @realtime (modules/hardware/pipewire/system.nix
  # already puts the user in that group) so it doesn't touch this machine's
  # non-audio work.
  security.pam.loginLimits = [
    {
      domain = "@realtime";
      item = "rtprio";
      type = "-";
      value = "99";
    }
    {
      domain = "@realtime";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
  ];

  networking = {
    interfaces.enp11s0f0np0.ipv4.addresses = [
      {
        address = "192.168.20.86";
        prefixLength = 24;
      }
    ];
    defaultGateway = "192.168.20.1";
    # the UDM's server-VLAN address; hara sits on the trusted VLAN but resolves against it
    nameservers = [config.lab.net.gateway];
    search = ["mesa.tetra.cool"];
  };

  networking.firewall.allowedUDPPorts = [51820];

  # physical cabling for the topology diagram; the address is on the trusted VLAN, so
  # attach the interface to that network or it renders detached
  topology.self.interfaces.enp11s0f0np0 = {
    network = "mesa-trusted-vlan";
    physicalConnections = [
      (config.lib.topology.mkConnection "tengigablort" "eth1")
    ];
  };

  # paws off!
  system.stateVersion = "25.11";
}
