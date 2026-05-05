{...}: {
  boot = {
    kernelParams = [
      "preempt=full"
    ];

    kernelModules = ["tcp_bbr"];

    kernel.sysctl = {
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.core.default_qdisc" = "fq";
    };
  };
}
