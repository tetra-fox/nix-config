# the proxmox-VM network shape every site shares: static v4 on the server-VLAN NIC, an
# optional isolated internal-VLAN NIC, and the topology parent edge. imported by each
# site facts file; the per-site deltas (domain, dataDir, internalCidr, proxmox parent)
# stay in the site file, per-host facts (hostIp, internalIp, multi-node proxmoxParent)
# in the host file.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # both site VLANs are /24; stated once so the address blocks and the dhcp announce
  # below can't drift apart
  prefixLength = 24;
  iface = config.lab.site.serverInterface;
in {
  networking = {
    useDHCP = false;
    defaultGateway = lib.mkDefault config.lab.net.gateway;
    nameservers = lib.mkDefault [config.lab.net.gateway];

    interfaces.${iface} = {
      mtu = 9000; # proxmox bridges + the switch run 9000 end-to-end at both sites
      ipv4.addresses = [
        {
          address = config.lab.site.hostIp;
          inherit prefixLength;
        }
      ];
    };

    # the isolated internal VLAN (VLAN 1010) for VM east-west traffic. no gateway/DNS
    # here (those stay on the server VLAN); no route off itself by design. only on
    # hosts that declare an internalIp.
    interfaces.${config.lab.site.internalInterface} = lib.mkIf (config.lab.site.internalIp != null) {
      mtu = 9000;
      ipv4.addresses = [
        {
          address = config.lab.site.internalIp;
          inherit prefixLength;
        }
      ];
    };
  };

  systemd = {
    # the fleet is statically addressed, so these hosts never send a DHCP request and the
    # router's client list has nothing but a MAC to label them with. a DHCPINFORM says
    # "already at this address, here is my name" and carries option 12, which is what the
    # router shows.
    #
    # -T runs the exchange and prints what it would have applied instead of applying it, so
    # the packet still goes out while dhcpcd leaves the interface alone. without it dhcpcd
    # takes the interface over and replaces the static routes with its own metric-1002 copies.
    # -4 because the internal VLAN runs no DHCP and fairlane's WAN is dual-stack, so a v6
    # solicit here would pick up a lease nothing asked for.
    services.dhcp-announce = lib.mkIf (config.lab.site.hostIp != null) {
      description = "announce this host's name to the site dhcp server";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        # leading "-": a router that is down or ignores INFORM must not fail the unit, which
        # would fire the fleet's "systemd unit failed" alert over a cosmetic announcement.
        # errors still reach the journal, only the exit status is dropped.
        ExecStart = "-${pkgs.dhcpcd}/bin/dhcpcd -T -4 -t 10 -s ${config.lab.site.hostIp}/${toString prefixLength} -h ${config.networking.hostName} ${iface}";
        # -T dumps every lease variable it would have used; that is a 20-line block per run
        # and none of it is news. stderr stays so real failures are visible.
        StandardOutput = "null";
      };
    };

    # the router forgets the name when its own lease table is cleared, so refresh rather than
    # relying on the boot-time run alone. one udp packet, spread so the fleet doesn't answer
    # in lockstep
    timers.dhcp-announce = lib.mkIf (config.lab.site.hostIp != null) {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "hourly";
        RandomizedDelaySec = "5m";
        Persistent = true;
      };
    };

    # the site data root, owned once here instead of per host; only the group varies
    tmpfiles.rules = lib.mkIf (config.lab.site.dataDir != null) [
      "d ${config.lab.site.dataDir} 0755 root ${config.lab.site.dataDirGroup} -"
    ];
  };

  topology.self = {
    parent = config.lab.site.proxmoxParent;
    guestType = "vm";
    interfaces.${config.lab.site.serverInterface} = {
      virtual = true;
      physicalConnections = [(config.lib.topology.mkConnection config.lab.site.proxmoxParent "vmbr0.10")];
    };
    interfaces.${config.lab.site.internalInterface} = lib.mkIf (config.lab.site.internalIp != null) {
      virtual = true;
      physicalConnections = [(config.lib.topology.mkConnection config.lab.site.proxmoxParent "vmbr0.1010")];
    };
  };
}
