# render: `just update-topology`
{config, ...}: let
  inherit (config.lib.topology) mkInternet mkRouter mkSwitch mkConnection;
  # appliance addresses come from the site facts (lab.appliances). every host of a site
  # carries them; the store hosts are just an arbitrary stable anchor each
  mesaAppliances = config.nixosConfigurations.mesa-store-01.config.lab.appliances;
  fairlaneAppliances = config.nixosConfigurations.fairlane-store-01.config.lab.appliances;
in {
  # mesa and fairlane reuse the same cidrs (192.168.10/20/30), so networks are
  # namespaced per-site or the two sites render as one L2 segment
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
    # isolated east-west fabric (postgres, NFS, monitoring); no gateway/WAN/inter-vlan
    mesa-internal-vlan = {
      name = "mesa Internal VLAN (1010, isolated)";
      cidrv4 = "10.10.0.0/24";
    };

    fairlane-server-vlan = {
      name = "fairlane Server VLAN";
      cidrv4 = "192.168.10.0/24";
    };

    # same isolated east-west fabric as mesa's, physically separate. no gateway/WAN/inter-vlan.
    fairlane-internal-vlan = {
      name = "fairlane Internal VLAN (1010, isolated)";
      cidrv4 = "10.10.0.0/24";
    };
  };

  nodes = {
    internet = mkInternet {
      connections = [
        (mkConnection "udm-pro-se" "eth8")
        (mkConnection "fairlane-udm" "eth8")
      ];
    };

    # ---- mesa site ----

    udm-pro-se = mkRouter "PuppygirlPlaypen" {
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

    tengigablort = mkSwitch "TenGigaBlort" {
      info = "USW-Pro-XG-10-PoE";
      interfaceGroups = [["eth0" "eth1" "eth2" "eth3" "eth4" "eth5" "eth6" "eth7" "eth8" "eth9"] ["sfp0" "sfp1"]];
      connections = {
        eth0 = mkConnection "xg-8" "sfp0";
        eth1 = mkConnection "hara" "enp11s0f0np0";
      };
    };

    xg-8 = mkSwitch "Pro XG 8 PoE" {
      info = "USW-Pro-XG-8-PoE";
      interfaceGroups = [["eth0" "eth1" "eth2" "eth3" "eth4" "eth5" "eth6" "eth7"] ["sfp0" "sfp1"]];
      connections = {
        eth1 = mkConnection "milkfish" "enp10s0f0";
        sfp0 = mkConnection "tengigablort" "eth0";
      };
    };

    milkfish = {
      name = "milkfish";
      deviceType = "server";
      hardware.info = "Proxmox VE 9";
      icon = ./images/icons/proxmox.svg;
      interfaces = {
        enp10s0f0 = {
          addresses = [];
        };
        "vmbr0.10" = {
          addresses = [mesaAppliances.proxmoxIp];
          network = "mesa-server-vlan";
          virtual = true;
        };
        "vmbr0.20" = {
          addresses = [];
          network = "mesa-trusted-vlan";
          virtual = true;
        };
        "vmbr0.30" = {
          addresses = [];
          network = "mesa-iot-vlan";
          virtual = true;
        };
        # no host address: milkfish doesn't participate, it just bridges the segment
        "vmbr0.1010" = {
          addresses = [];
          network = "mesa-internal-vlan";
          virtual = true;
        };
      };
    };

    homeassistant = {
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
        # the internal-VLAN leg: inter-VM traffic (NFS backups to store-01, the edge's
        # home.* vhost, prometheus scrapes) uses this address exclusively
        enp0s19 = {
          addresses = [mesaAppliances.haosIp];
          network = "mesa-internal-vlan";
          virtual = true;
          physicalConnections = [(mkConnection "milkfish" "vmbr0.1010")];
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

    # ---- fairlane site ----

    fairlane-udm = mkRouter "Fairlane" {
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

    fairlane-usw = mkSwitch "USW Pro HD 24 PoE" {
      info = "USW-Pro-HD-24-PoE";
      # 24 rj45 ports plus 4 sfp ports on top
      interfaceGroups = [
        ["port1" "port2" "port3" "port4" "port5" "port6" "port7" "port8" "port9" "port10" "port11" "port12" "port13" "port14" "port15" "port16" "port17" "port18" "port19" "port20" "port21" "port22" "port23" "port24"]
        ["port25" "port26" "port27" "port28"]
      ];
      connections = {
        # udm uplink lands on sfp port 27
        "port27" = mkConnection "fairlane-udm" "port10";
        # plush's trunk nic is on rj45 port 17
        "port17" = mkConnection "plush" "nic0";
        # pooltoy's trunk nic is on rj45 port 20
        "port20" = mkConnection "pooltoy" "enp89s0";
      };
    };

    # db-01, dns-01, edge-01 run here; the rest of the fleet is on pooltoy.
    plush = {
      name = "plush";
      deviceType = "server";
      hardware.info = "Proxmox VE 9";
      icon = ./images/icons/proxmox.svg;
      interfaces = {
        nic0 = {
          addresses = [];
        };
        "vmbr0.10" = {
          addresses = ["192.168.10.212"];
          network = "fairlane-server-vlan";
          virtual = true;
        };
        # no host address: plush just bridges the isolated segment for its VMs' ens19
        "vmbr0.1010" = {
          addresses = [];
          network = "fairlane-internal-vlan";
          virtual = true;
        };
      };
    };

    pooltoy = {
      name = "pooltoy";
      deviceType = "server";
      hardware.info = "Proxmox VE 9";
      icon = ./images/icons/proxmox.svg;
      interfaces = {
        enp89s0 = {
          addresses = [];
        };
        "vmbr0.10" = {
          addresses = ["192.168.10.7"];
          network = "fairlane-server-vlan";
          virtual = true;
        };
        "vmbr0.1010" = {
          addresses = [];
          network = "fairlane-internal-vlan";
          virtual = true;
        };
      };
    };

    # the fairlane-* fleet (store/db/svc/mon/edge/dns) comes from each host's topology.self via
    # modules/sites/fairlane.nix, which reads lab.site.proxmoxParent to attach the VM to plush or
    # pooltoy's vmbr0.10 (+ vmbr0.1010 for hosts with an internalIp), same as mesa-svc-01.

    fairlane-homeassistant = {
      name = "homeassistant";
      deviceType = "vm";
      parent = "plush";
      guestType = "vm";
      icon = ./images/icons/home-assistant.svg;
      hardware.info = "Home Assistant OS";
      interfaces.ens18 = {
        addresses = [fairlaneAppliances.haosIp];
        network = "fairlane-server-vlan";
        virtual = true;
        physicalConnections = [(mkConnection "plush" "vmbr0.10")];
      };
    };
  };
}
