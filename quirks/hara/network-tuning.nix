{pkgs, ...}: let
  iface = ["enp11s0f0np0" "enp11s0f0np1"]; # MCX4121A-ACAT
in {
  boot.kernel.sysctl = {
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.core.rmem_default" = 16777216;
    "net.core.wmem_default" = 16777216;
    "net.ipv4.tcp_rmem" = "4096 87380 134217728";
    "net.ipv4.tcp_wmem" = "4096 65536 134217728";
    "net.core.netdev_max_backlog" = 250000;
  };

  # ring buffers + jumbo MTU; bound to device so it survives NM up/down cycles
  systemd.services."ethtool-tune@" = {
    description = "Tune %i (ring buffers, MTU)";
    after = ["sys-subsystem-net-devices-%i.device"];
    bindsTo = ["sys-subsystem-net-devices-%i.device"];
    wantedBy = ["sys-subsystem-net-devices-%i.device"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "${pkgs.ethtool}/bin/ethtool -G %i rx 8192 tx 8192"
        "${pkgs.iproute2}/bin/ip link set %i mtu 9000"
      ];
    };
  };

  systemd.targets.multi-user.wants = map (i: "ethtool-tune@${i}.service") iface;
}
