{
  config,
  lib,
  modules,
  pkgs,
  username,
  ...
}: let
  nmSecrets = ["nm/puppygirlplaypen" "nm/fairlane"];
in {
  imports = [
    modules.profiles.workstation.system
    # defaults to secrets/hara.yaml
    modules.platform.sops.system

    modules.desktop.drkonqi.system
    modules.desktop.greetd.system
    modules.desktop.hyprland.system
    modules.desktop.kde.system
    modules.hardware.nvidia.system
    modules.hardware.ddcci.system
    # modules.hardware.openrgb.system
    modules.desktop.steam.system
    modules.desktop.sunshine.system
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

  # named by permanent MAC so a PCI slot change can't rename them
  systemd.network.links = lib.mapAttrs' (name: mac:
    lib.nameValuePair "10-${name}" {
      matchConfig.PermanentMACAddress = mac;
      linkConfig.Name = name;
    }) {
    sfp0 = "b8:ce:f6:ea:ad:6c"; # ConnectX-4 Lx port 1
    sfp1 = "b8:ce:f6:ea:ad:6d"; # ConnectX-4 Lx port 2
    lan0 = "18:c0:4d:04:8f:eb"; # onboard igb
    wifi0 = "8c:c6:81:9e:a8:c2"; # iwlwifi
  };

  # one dotenv block per NM profile in secrets/hara.yaml, plus the mount.cifs credentials file
  sops.secrets = lib.genAttrs (nmSecrets ++ ["smb/store"]) (_: {});

  # the per-user `store` samba share. fully qualified because only the wired profile sets the
  # mesa search domain
  fileSystems."/mnt/store" = {
    device = "//mesa-store-01.mesa.tetra.cool/store";
    fsType = "cifs";
    options = [
      "credentials=${config.sops.secrets."smb/store".path}"
      "vers=3.1.1"
      # the server requires encryption
      "seal"
      "uid=${username}"
      "gid=users"
      "nofail"
      # caps mount and unmount, so a dead store box can't hold up an access or a shutdown for
      # the default 90s
      "x-systemd.mount-timeout=10s"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "_netdev"
    ];
  };

  networking = {
    networkmanager = {
      # prevent NM from autogenerating profiles, we declare them
      settings.main.no-auto-default = "*";

      ensureProfiles = {
        environmentFiles = map (s: config.sops.secrets.${s}.path) nmSecrets;

        profiles = {
          ethernet = {
            connection = {
              id = "Ethernet";
              type = "ethernet";
              interface-name = "sfp0";
            };
            ipv4 = {
              method = "manual";
              address1 = "192.168.20.86/24,192.168.20.1";
              # server-VLAN gateway, hara is on the trusted VLAN
              dns = "${config.lab.net.gateway};";
              dns-search = "mesa.tetra.cool;";
            };
            ipv6.method = "auto";
          };

          puppygirlplaypen = {
            connection = {
              id = "PuppygirlPlaypen";
              type = "wifi";
              interface-name = "wifi0";
            };
            wifi = {
              ssid = "PuppygirlPlaypen";
              mode = "infrastructure";
            };
            wifi-security = {
              key-mgmt = "sae";
              psk = "$PUPPYGIRLPLAYPEN_PSK";
            };
            ipv4.method = "auto";
            ipv6.method = "auto";
          };

          fairlane = {
            connection = {
              id = "fairlane";
              type = "wireguard";
              interface-name = "fairlane";
              autoconnect = false;
            };
            wireguard.private-key = "$FAIRLANE_WG_PRIVATE_KEY";
            "wireguard-peer.ftaCyjMGvM5td69yufR94zSL92ZxUiRrRRtJkfmC7wc=" = {
              endpoint = "fairlane.tetra.cool:51820";
              allowed-ips = "0.0.0.0/0;";
            };
            ipv4 = {
              method = "manual";
              address1 = "192.168.100.5/32";
              dns = "192.168.100.1;";
            };
            ipv6.method = "disabled";
          };
        };
      };
    };

    firewall.allowedUDPPorts = [51820];
  };

  # without the network it renders detached
  topology.self.interfaces.sfp0 = {
    network = "mesa-trusted-vlan";
    physicalConnections = [
      (config.lib.topology.mkConnection "tengigablort" "eth1")
    ];
  };

  # paws off!
  system.stateVersion = "25.11";
}
