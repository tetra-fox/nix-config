_: {
  boot = {
    kernelParams = [
      "preempt=full"
    ];

    kernelModules = ["tcp_bbr"];

    kernel.sysctl = {
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.core.default_qdisc" = "fq";
      "kernel.perf_event_paranoid" = 1;
      "kernel.perf_event_mlock_kb" = 2048;
    };
  };
}
