# render: `nix run .#update-topology`
{config, ...}: let
  inherit (config.lib.topology) mkInternet mkRouter mkSwitch mkConnection;
in {
  # mesa and fairlane are separate physical sites that happen to share the same
  # private vlan layout (192.168.10/20/30). the cidrs collide, so networks are
  # namespaced per-site to keep the two sites from rendering as one L2 segment.
  networks = {
    mesa-server-vlan = {
      name = "mesa Server VLAN";
      cidrv4 = "192.168.10.0/24";
    };
    mesa-trusted-vlan = {
      name = "mesa Trusted VLAN";
      cidrv4 = "192.168.20.0/24";
    };
    mesa-iot-vlan = {
      name = "mesa IoT VLAN";
      cidrv4 = "192.168.30.0/24";
    };
    # isolated east-west fabric for VM-to-VM traffic (postgres, NFS, monitoring). VLAN
    # 1010, no gateway/WAN/inter-vlan. every mesa VM's ens19 lands here by CIDR match.
    mesa-internal-vlan = {
      name = "mesa Internal VLAN (1010, isolated)";
      cidrv4 = "10.10.0.0/24";
    };

    fairlane-server-vlan = {
      name = "fairlane Server VLAN";
      cidrv4 = "192.168.10.0/24";
    };
  };

  nodes.internet = mkInternet {
    connections = [
      (mkConnection "udm-pro-se" "eth8")
      (mkConnection "fairlane-udm" "eth8")
    ];
  };

  # ---- mesa site ----

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
        network = "mesa-server-vlan";
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
      network = "mesa-server-vlan";
      virtual = true;
    };
    interfaces."vmbr0.20" = {
      addresses = [];
      network = "mesa-trusted-vlan";
      virtual = true;
    };
    interfaces."vmbr0.30" = {
      addresses = [];
      network = "mesa-iot-vlan";
      virtual = true;
    };
    # the isolated internal VLAN bridge; the mesa VMs' ens19 ride this for east-west
    # traffic. no host address on it (milkfish doesn't participate, it just bridges).
    interfaces."vmbr0.1010" = {
      addresses = [];
      network = "mesa-internal-vlan";
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
        network = "mesa-server-vlan";
        virtual = true;
        physicalConnections = [(mkConnection "milkfish" "vmbr0.10")];
      };
      enp0s20 = {
        addresses = ["192.168.30.5"];
        network = "mesa-iot-vlan";
        virtual = true;
        physicalConnections = [(mkConnection "milkfish" "vmbr0.30")];
      };
      enp0s21 = {
        addresses = ["192.168.20.56"];
        network = "mesa-trusted-vlan";
        virtual = true;
        physicalConnections = [(mkConnection "milkfish" "vmbr0.20")];
      };
    };
  };

  # the mesa resolver is now mesa-dns-01/02 (NixOS), which self-render from their topology.self
  # like every other mesa VM. the old Technitium LXC node is gone; the .53 they serve is a
  # floating keepalived VIP, not a host, so it isn't a node here.

  # ---- fairlane site ----

  nodes.fairlane-udm = mkRouter "Fairlane" {
    info = "UDM-SE";
    interfaceGroups = [
      ["eth0" "eth1" "eth2" "eth3" "eth4" "eth5" "eth6" "eth7"]
      ["eth8"]
      ["sfp0" "sfp1"]
    ];
    interfaces = {
      # sfp port 10 on the udm uplinks to the switch (sfp port 27 on the pro hd 24)
      "port10" = {
        addresses = ["192.168.10.1"];
        network = "fairlane-server-vlan";
      };
    };
    connections."port10" = mkConnection "fairlane-usw" "port27";
  };

  nodes.fairlane-usw = mkSwitch "USW Pro HD 24 PoE" {
    info = "USW-Pro-HD-24-PoE";
    # 24 rj45 ports plus 4 sfp ports on top
    interfaceGroups = [
      ["port1" "port2" "port3" "port4" "port5" "port6" "port7" "port8" "port9" "port10" "port11" "port12" "port13" "port14" "port15" "port16" "port17" "port18" "port19" "port20" "port21" "port22" "port23" "port24"]
      ["port25" "port26" "port27" "port28"]
    ];
    connections = {
      # udm uplink lands on sfp port 27
      "port27" = mkConnection "fairlane-udm" "port10";
      # pooltoy's trunk nic is on rj45 port 20
      "port20" = mkConnection "pooltoy" "enp89s0";
    };
  };

  nodes.pooltoy = {
    name = "pooltoy";
    deviceType = "server";
    hardware.info = "Proxmox VE 9";
    icon = ./images/icons/proxmox.svg;
    interfaces.enp89s0 = {
      addresses = [];
    };
    interfaces."vmbr0.10" = {
      addresses = ["192.168.10.7"];
      network = "fairlane-server-vlan";
      virtual = true;
    };
  };

  # fairlane-svc-01 itself comes from the host's topology.self (hosts/fairlane-svc-01),
  # same as mesa-svc-01. it attaches to pooltoy's vmbr0.10, declared above.

  nodes.fairlane-homeassistant = {
    name = "homeassistant";
    deviceType = "vm";
    parent = "pooltoy";
    guestType = "vm";
    icon = ./images/icons/home-assistant.svg;
    hardware.info = "Home Assistant OS";
    interfaces.ens18 = {
      addresses = ["192.168.10.215"];
      network = "fairlane-server-vlan";
      virtual = true;
      physicalConnections = [(mkConnection "pooltoy" "vmbr0.10")];
    };
  };

  nodes.fairlane-adguard = {
    name = "adguard";
    deviceType = "container";
    parent = "pooltoy";
    guestType = "lxc";
    # TODO: drop an adguard icon in images/icons and reference it here
    hardware.info = "AdGuard Home";
    interfaces.eth0 = {
      addresses = ["192.168.10.53"];
      network = "fairlane-server-vlan";
      virtual = true;
      physicalConnections = [(mkConnection "pooltoy" "vmbr0.10")];
    };
  };
}
