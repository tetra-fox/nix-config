{ ... }:

{
  services.hardware.openrgb = {
    enable = true;
  };

  # required for SMBus communication (e.g. DRAM LEDs)
  boot.kernelParams = [ "acpi_enforce_resources=lax" ];
}
