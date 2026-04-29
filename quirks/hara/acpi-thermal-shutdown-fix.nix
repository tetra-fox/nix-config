{...}: {
  # acpitz thermal_zone0 (PCT0) reports bogus values on resume from suspend -
  # baseline reads as 17C, then trips "critical" and triggers an emergency
  # poweroff. k10temp + the CPU's own hardware thermal protection are the real
  # safety net, so disable the lying ACPI thermal subsystem entirely.
  boot.kernelParams = ["thermal.off=1"];
}
