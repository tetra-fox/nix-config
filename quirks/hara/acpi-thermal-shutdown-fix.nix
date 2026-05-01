{...}: {
  # acpitz thermal_zone0 (PCT0) reports bad values on resume from suspend
  # baseline reads as 17C, then trips "critical" and triggers an emergency
  # poweroff
  boot.kernelParams = ["thermal.off=1"];
}
