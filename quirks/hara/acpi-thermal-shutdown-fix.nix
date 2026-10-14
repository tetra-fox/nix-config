_: {
  # acpitz thermal_zone0 (PCT0) reads garbage after resume, trips "critical" and powers off
  boot.kernelParams = ["thermal.off=1"];
}
