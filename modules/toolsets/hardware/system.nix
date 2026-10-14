# linux only. on a plain VM this just reports qemu, import on bare metal and passthrough hosts
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    dmidecode
    lm_sensors
    lshw
    pciutils # lspci
    usbutils # lsusb
  ];
}
