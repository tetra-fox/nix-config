# render: `nix run .#update-topology`
{config, ...}: let
  inherit (config.lib.topology) mkInternet mkRouter mkSwitch mkConnection;
in {
  networks = {
    server-vlan = {
      name = "Server VLAN";
      cidrv4 = "192.168.10.0/24";
    };
    trusted-vlan = {
      name = "Trusted VLAN";
      cidrv4 = "192.168.20.0/24";
    };
    iot-vlan = {
      name = "IoT VLAN";
      cidrv4 = "192.168.30.0/24";
    };
    milkfish-internal = {
      name = "milkfish SDN internal";
      cidrv4 = "10.10.0.0/24";
    };
  };

  nodes.internet = mkInternet {
    connections = mkConnection "udm-pro-se" "eth8";
  };

  nodes.udm-pro-se = mkRouter "PuppygirlPlaypen" {
    info = "UDM-SE";
    interfaceGroups = [
      ["eth0" "eth1" "eth2" "eth3" "eth4" "eth5" "eth6" "eth7"]
      ["eth8"]
      ["sfp0" "sfp1"]
    ];
    interfaces = {
      sfp1 = {
        addresses = ["192.168.10.1" "192.168.20.1"];
        network = "server-vlan";
      };
    };
    connections.sfp1 = mkConnection "tengigablort" "sfp0";
  };

  nodes.tengigablort = mkSwitch "TenGigaBlort" {
    info = "USW-Pro-XG-10-PoE";
    interfaceGroups = [["eth0" "eth1" "eth2" "eth3" "eth4" "eth5" "eth6" "eth7" "eth8" "eth9"] ["sfp0" "sfp1"]];
    connections = {
      eth0 = mkConnection "xg-8" "sfp0";
      eth1 = mkConnection "hara" "enp11s0f0np0";
    };
  };

  nodes.xg-8 = mkSwitch "Pro XG 8 PoE" {
    info = "USW-Pro-XG-8-PoE";
    interfaceGroups = [["eth0" "eth1" "eth2" "eth3" "eth4" "eth5" "eth6" "eth7"] ["sfp0" "sfp1"]];
    connections = {
      eth1 = mkConnection "milkfish" "enp10s0f0";
      sfp0 = mkConnection "tengigablort" "eth0";
    };
  };

  nodes.milkfish = {
    name = "milkfish";
    deviceType = "server";
    hardware.info = "Proxmox VE 9";
    icon = ./images/icons/proxmox.svg;
    interfaces.enp10s0f0 = {
      addresses = [];
    };
    interfaces."vmbr0.10" = {
      addresses = ["192.168.10.2"];
      network = "server-vlan";
      virtual = true;
    };
    interfaces."vmbr0.20" = {
      addresses = [];
      network = "trusted-vlan";
      virtual = true;
    };
    interfaces."vmbr0.30" = {
      addresses = [];
      network = "iot-vlan";
      virtual = true;
    };
    interfaces.vmbr10 = {
      addresses = ["10.10.0.1"];
      network = "milkfish-internal";
      virtual = true;
    };
  };

  nodes.homeassistant = {
    name = "homeassistant";
    deviceType = "vm";
    parent = "milkfish";
    guestType = "vm";
    icon = ./images/icons/home-assistant.svg;
    hardware.info = "Home Assistant OS";
    interfaces = {
      enp0s18 = {
        addresses = ["192.168.10.5"];
        network = "server-vlan";
        virtual = true;
        physicalConnections = [(mkConnection "milkfish" "vmbr0.10")];
      };
      enp0s19 = {
        addresses = ["10.10.0.20"];
        network = "milkfish-internal";
        virtual = true;
        physicalConnections = [(mkConnection "milkfish" "vmbr10")];
      };
      enp0s20 = {
        addresses = ["192.168.30.5"];
        network = "iot-vlan";
        virtual = true;
        physicalConnections = [(mkConnection "milkfish" "vmbr0.30")];
      };
      enp0s21 = {
        addresses = ["192.168.20.56"];
        network = "trusted-vlan";
        virtual = true;
        physicalConnections = [(mkConnection "milkfish" "vmbr0.20")];
      };
    };
  };

  nodes.technitium = {
    name = "technitiumdns";
    deviceType = "container";
    parent = "milkfish";
    guestType = "lxc";
    icon = ./images/icons/technitium.svg;
    hardware.info = "Technitium DNS";
    interfaces.eth0 = {
      addresses = ["192.168.10.53"];
      network = "server-vlan";
      virtual = true;
      physicalConnections = [(mkConnection "milkfish" "vmbr0.10")];
    };
  };
}
